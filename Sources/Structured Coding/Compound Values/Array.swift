private import JavaScriptObjectNotation

// MARK: - Schema

@StructuredCodable
public struct StructuredArraySchema<ElementSchema: StructuredCodingSchema>: StructuredCodingSchema {
  public init(description: String?) {
    self.description = description
    self.items = ElementSchema()
  }
  private let description: String?
  private let items: ElementSchema
}

// MARK: - Encoding

extension Array: StructuredEncodable where Element: StructuredEncodable {

  public typealias Schema = StructuredArraySchema<Element.Schema>

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeArray { arrayEncoder in
      for element in self {
        try arrayEncoder.encodeElement { stream in
          try stream.withEncoder { encoder in
            try element.encode(to: &encoder)
          }
        }
      }
    }
  }

}

// MARK: - Decoding

extension Array: StructuredDecodable where Element: StructuredDecodable {

  public typealias Schema = StructuredArraySchema<Element.Schema>

  public static func initialValueForDecoding(isMutable: Bool) -> sending [Element]? {
    isMutable ? [] : nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == [Element] {
    if accessor.isMutable {
      try await decodeStreamed(from: &decoder, in: context, using: accessor)
    } else {
      try await decodeBuffered(from: &decoder, in: context, using: accessor)
    }
  }

  /// Streams each decoded element into the already-initialized destination
  /// (`initialValueForDecoding` returned `[]`) as it arrives.
  private static func decodeStreamed<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == [Element] {
    try await decoder.stream.decodeArray { arrayDecoder in
      while !arrayDecoder.isAtEnd {
        try await arrayDecoder.decodeElement { stream in
          try await stream.withDecoder { decoder in
            let index: Int
            if let initialValue = Element.initialValueForDecoding(isMutable: accessor.isMutable) {
              index = try await accessor.mutateValue(applying: initialValue) {
                array, initialValue in
                let index = array.count
                array.append(initialValue)
                return index
              }
            } else {
              index = try await accessor.accessValue(applying: ()) { array, _ in
                array.endIndex
              }
            }
            try await accessor.withElementAccessor(at: index) { accessor in
              try await Element.decode(from: &decoder, in: context, using: accessor)
            }
          }
        }
      }
    }
  }

  /// An immutable destination has no value to stream into
  /// (`initialValueForDecoding` returned `nil`), so the elements are buffered
  /// locally and the array is initialized all at once.
  private static func decodeBuffered<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == [Element] {
    let elements = try await decoder.stream.decodeArray { arrayDecoder in
      var elements: [Element] = []
      while !arrayDecoder.isAtEnd {
        elements.append(
          try await arrayDecoder.decodeElement { stream in
            try await stream.withDecoder { decoder in
              try await Element.decode(from: &decoder, in: context)
            }
          }
        )
      }
      return elements
    }
    try await accessor.initializeValue(to: elements)
  }

}

// MARK: - Accessor

extension StructuredAccessor where Self: ~Escapable {

  func withElementAccessor<T, U>(
    at index: Int,
    _ body: (ArrayElementAccessor<Self, T>) async throws -> sending U
  ) async throws -> sending U {
    let accessor = ArrayElementAccessor(base: self, index: index)
    return try await body(accessor)
  }

}

struct ArrayElementAccessor<
  Base: StructuredAccessor & ~Escapable, Element
>: StructuredAccessor, ~Escapable
where Base.Value == [Element] {

  var isMutable: Bool { base.isMutable }

  func initializeValue(to value: sending Element) async throws {
    let index = index
    return try await base.mutateValue(applying: value) { array, newValue in
      if array.endIndex == index {
        array.append(newValue)
      } else {
        guard array.indices.contains(index) else {
          throw AccessorError.indexOutOfBounds
        }
        array[index] = newValue
      }
    }
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing Element, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    let index = index
    return try await base.accessValue(applying: delta) { array, delta in
      guard array.indices.contains(index) else {
        throw AccessorError.indexOutOfBounds
      }
      return try await apply(array[index], delta)
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Element, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    let index = index
    return try await base.mutateValue(applying: delta) { array, delta in
      guard array.indices.contains(index) else {
        throw AccessorError.indexOutOfBounds
      }
      return try await apply(&array[index], delta)
    }
  }

  @_lifetime(copy base)
  init(base: consuming Base, index: Int) {
    self.base = base
    self.index = index
  }
  fileprivate let base: Base
  fileprivate let index: Int

}
