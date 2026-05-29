private import JavaScriptObjectNotation

public import struct Foundation.Decimal

public protocol StructuredEnumeration: StructuredCodable {

  associatedtype CodingStyle: StructuredEnumerationCodingStyle = StructuredEnumerationCodingStyleObjectProperties
  static var codingStyle: CodingStyle { get }

  associatedtype Cases
  static func cases() -> Cases

}

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public static var codingStyle: CodingStyle { CodingStyle() }

}

extension StructuredEnumeration where Self: RawRepresentable {

  public static var codingStyle: StructuredEnumerationCodingStyleRawValue { .rawValue }

  /// Raw-value enumerations carry no per-case associated values, so there are no
  /// `StructuredEnumerationCase`s to enumerate; the case is determined by `init(rawValue:)`.
  public static func cases() -> Void { () }

}

// MARK: - Encoding

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public func encode<each AssociatedValue: StructuredEncodable>(
    to encoder: inout StructuredEncoder
  ) throws
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let casesTuple = Self.cases()
    let cases = (repeat each casesTuple)
    try encoder.stream.encodeObject { objectEncoder in
      for `case` in repeat each cases {
        guard let associatedValue = `case`.accessor(self) else { continue }
        try objectEncoder.encodeProperty(`case`.name.stringValue) { stream in
          try stream.withEncoder { encoder in
            try associatedValue.encode(to: &encoder)
          }
        }
        return
      }
      throw EnumerationCodingError.noMatchingCase
    }
  }

}

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleInternallyTagged {

  public func encode<each AssociatedValue: StructuredObject>(
    to encoder: inout StructuredEncoder
  ) throws
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let discriminatorPropertyName = Self.codingStyle.discriminatorPropertyName
    let casesTuple = Self.cases()
    let cases = (repeat each casesTuple)
    try encoder.stream.encodeObject { objectEncoder in
      try objectEncoder.withPropertiesEncoder { propertiesEncoder in
        for `case` in repeat each cases {
          guard let associatedValue = `case`.accessor(self) else { continue }
          let caseName = `case`.name.stringValue
          try propertiesEncoder.encodeProperty(named: discriminatorPropertyName) { encoder in
            try caseName.encode(to: &encoder)
          }
          try associatedValue.encodeProperties(to: &propertiesEncoder)
          return
        }
        throw EnumerationCodingError.noMatchingCase
      }
    }
  }

}

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleTypeDiscriminated {

  public func encode<each AssociatedValue: StructuredEncodable>(
    to encoder: inout StructuredEncoder
  ) throws
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let casesTuple = Self.cases()
    let cases = (repeat each casesTuple)
    for `case` in repeat each cases {
      guard let associatedValue = `case`.accessor(self) else { continue }
      try associatedValue.encode(to: &encoder)
      return
    }
    throw EnumerationCodingError.noMatchingCase
  }

}

extension StructuredEnumeration
where
  Self: RawRepresentable,
  CodingStyle == StructuredEnumerationCodingStyleRawValue,
  RawValue == String
{

  public func encode(to encoder: inout StructuredEncoder) throws {
    try rawValue.encode(to: &encoder)
  }

}

extension StructuredEnumeration
where
  Self: RawRepresentable,
  CodingStyle == StructuredEnumerationCodingStyleRawValue,
  RawValue: FixedWidthInteger & Sendable
{

  public func encode(to encoder: inout StructuredEncoder) {
    encoder.stream.encode(rawValue)
  }

}

// MARK: - Decoding

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each AssociatedValue
  >(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>)
  {
    try await decoder.stream.decodeObject { objectDecoder in
      if objectDecoder.isAtEnd {
        throw EnumerationCodingError.noProperties
      }
      try await objectDecoder.decodeProperty(
        decodeValue: { name, stream in
          for `case` in repeat each cases() {
            if `case`.name.stringValue == name {
              try await `case`.decode(from: &stream, in: context, using: accessor)
              return
            }
          }
          throw EnumerationCodingError.unknownCase(name)
        }
      )
      guard objectDecoder.isAtEnd else {
        throw EnumerationCodingError.moreThanOneProperty
      }
    }
  }

}

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleInternallyTagged {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each AssociatedValue: StructuredObject
  >(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>)
  {
    try await decoder.stream.decodeObject { objectDecoder in
      let discriminator = try await objectDecoder.peekObjectProperty(
        named: codingStyle.discriminatorPropertyName.stringValue,
        peekPropertyValue: { try await $0.decodeString() }
      )
      guard let discriminator else {
        throw EnumerationCodingError.discriminatorNotFound
      }
      for `case` in repeat each cases() {
        guard `case`.name.stringValue == discriminator else {
          continue
        }
        try await context.withArena { arena in
          try await objectDecoder.decodeObjectProperties(in: arena) { propertiesDecoder in
            try await `case`.decodeProperties(
              discriminatorPropertyName: codingStyle.discriminatorPropertyName,
              from: &propertiesDecoder,
              in: context,
              using: accessor
            )
          }
        }
        return
      }
      throw EnumerationCodingError.unknownCase(discriminator)
    }
  }

}

extension StructuredEnumeration where CodingStyle == StructuredEnumerationCodingStyleTypeDiscriminated {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each AssociatedValue
  >(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>)
  {
    let kind = try await decoder.stream.peekValueKind()
    for `case` in repeat each cases() {
      guard `case`.kind == kind else {
        continue
      }
      try await `case`.decode(from: &decoder.stream, in: context, using: accessor)
      return
    }
    throw EnumerationCodingError.unknownKind(kind)
  }

}

extension StructuredEnumeration
where
  Self: RawRepresentable,
  CodingStyle == StructuredEnumerationCodingStyleRawValue,
  RawValue == String
{

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let rawValue = try await decoder.stream.decodeString()
    guard let value = Self(rawValue: rawValue) else {
      throw EnumerationCodingError.unknownRawValue(rawValue)
    }
    try await accessor.initializeValue(to: value)
  }

}

extension StructuredEnumeration
where
  Self: RawRepresentable,
  CodingStyle == StructuredEnumerationCodingStyleRawValue,
  RawValue: FixedWidthInteger & Sendable
{

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let number = try await decoder.stream.decodeNumber()
    let rawValue = try number.decode(as: RawValue.self)
    guard let value = Self(rawValue: rawValue) else {
      throw EnumerationCodingError.unknownRawValue("\(rawValue)")
    }
    try await accessor.initializeValue(to: value)
  }

}

// MARK: - Enumeration Cases

public struct StructuredEnumerationCase<Enumeration, AssociatedValue: StructuredDecodable> {

  let name: StructuredCodingKey
  let accessor: @Sendable (Enumeration) -> AssociatedValue?
  let initializer: @Sendable (AssociatedValue) -> sending Enumeration

  fileprivate let kind: JavaScriptObjectNotation.DecodingStream.ValueKind?

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: nil)
  }

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue == String {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: .string)
  }

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue == Bool {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: .boolean)
  }

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue: FixedWidthInteger {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: .number)
  }

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue: BinaryFloatingPoint {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: .number)
  }

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue == Decimal {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: .number)
  }

  public init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue: StructuredObject {
    self.init(name: name, accessor: accessor, initializer: initializer, kind: .object)
  }

  private init(
    name: StructuredCodingKey,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration,
    kind: JavaScriptObjectNotation.DecodingStream.ValueKind?
  ) {
    self.name = name
    self.accessor = accessor
    self.initializer = initializer
    self.kind = kind
  }

  fileprivate func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout DecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Enumeration {
    try await stream.withDecoder { decoder in
      try await accessor.withCaseAccessor(for: self) { accessor in
        if let initialValue = AssociatedValue.initialValueForDecoding(
          isMutable: accessor.isMutable
        ) {
          try await accessor.initializeValue(to: initialValue)
        }
        try await AssociatedValue.decode(
          from: &decoder,
          in: context,
          using: accessor
        )
      }
    }
  }

  fileprivate func decodeProperties<Accessor: StructuredAccessor & ~Escapable>(
    discriminatorPropertyName: StructuredCodingKey,
    from decoder: inout StructuredObjectPropertiesDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Enumeration,
    AssociatedValue: StructuredObject
  {
    try await accessor.withCaseAccessor(for: self) { accessor in
      if let initialValue = AssociatedValue.initialValueForDecoding(
        isMutable: accessor.isMutable
      ) {
        try await accessor.initializeValue(to: initialValue)
      }
      try await AssociatedValue.decodeProperties(
        from: &decoder,
        in: context,
        using: accessor,
        configuration: InternallyTaggedObjectPropertiesDecodingConfiguration(
          discriminatorPropertyName: discriminatorPropertyName,
          discriminator: name
        )
      )
    }
  }

}

private struct InternallyTaggedObjectPropertiesDecodingConfiguration:
  StructuredObjectPropertiesDecodingConfiguration
{
  let discriminatorPropertyName: StructuredCodingKey
  let discriminator: StructuredCodingKey

  typealias DecodingState = StructuredObjectPropertiesDecoder.Checkpoint<Void>
  func prepareForDecoding(
    from decoder: inout StructuredObjectPropertiesDecoder
  ) -> DecodingState {
    decoder.createCheckpoint()
  }
  func decodeAdditionalProperties(
    from decoder: inout StructuredObjectPropertiesDecoder,
    with checkpoint: DecodingState
  ) async throws {
    try await decoder.decodeIfNextPropertyNamed(
      discriminatorPropertyName.stringValue,
      checkpoint: checkpoint,
      decode: { stream in
        let observed = try await stream.decodeString()
        let expected = discriminator.stringValue
        guard observed == expected else {
          throw EnumerationCodingError.invalidDiscriminator(observed: observed, expected: expected)
        }
      }
    )
  }
}

// MARK: - Coding Style

public protocol StructuredEnumerationCodingStyle: Sendable {

}

public struct StructuredEnumerationCodingStyleObjectProperties: StructuredEnumerationCodingStyle {
}

extension StructuredEnumerationCodingStyle where Self == StructuredEnumerationCodingStyleInternallyTagged {
  public static func internallyTagged(discriminatorPropertyName: StructuredCodingKey) -> Self {
    StructuredEnumerationCodingStyleInternallyTagged(discriminatorPropertyName: discriminatorPropertyName)
  }
}

public struct StructuredEnumerationCodingStyleInternallyTagged: StructuredEnumerationCodingStyle {
  public init(discriminatorPropertyName: StructuredCodingKey) {
    self.discriminatorPropertyName = discriminatorPropertyName
  }
  let discriminatorPropertyName: StructuredCodingKey
}

extension StructuredEnumerationCodingStyle where Self == StructuredEnumerationCodingStyleTypeDiscriminated {
  public static var typeDiscriminated: Self { Self() }
}

public struct StructuredEnumerationCodingStyleTypeDiscriminated: StructuredEnumerationCodingStyle {
  public init() {}
}

extension StructuredEnumerationCodingStyle where Self == StructuredEnumerationCodingStyleRawValue {
  static var rawValue: Self { Self() }
}

/// A raw-value enumeration is encoded as a bare JSON scalar — the case's
/// `rawValue` — with no wrapper: a `String`-backed enum encodes as a JSON string
/// (`"red"`) and an integer-backed enum as a JSON number (`2`). Decoding reads the
/// whole scalar and maps it back to a case with `init(rawValue:)`; a scalar of the
/// wrong JSON kind, or one that names no case, is rejected.
///
/// This is the style for `RawRepresentable` enumerations. Such an enum needs no
/// boilerplate beyond declaring the raw type — the coding style, `cases()`, and
/// the decoding itself are all supplied for it:
///
/// ```swift
/// enum Color: String, StructuredEnumeration {
///   case red, green, blue
/// }
/// ```
///
/// Because the case is unknown until the entire scalar has been read and matched,
/// a raw-value enumeration has no observable partial value mid-stream.
public struct StructuredEnumerationCodingStyleRawValue: StructuredEnumerationCodingStyle {
}

// MARK: - Accessor

extension StructuredAccessor where Self: ~Escapable {

  fileprivate func withCaseAccessor<T, U>(
    for `case`: StructuredEnumerationCase<Self.Value, T>,
    _ body: (EnumerationCaseAccessor<Self, T>) async throws -> sending U
  ) async throws -> sending U {
    let accessor = EnumerationCaseAccessor(
      case: `case`,
      base: self
    )
    return try await body(accessor)
  }

}

private struct EnumerationCaseAccessor<
  Base: StructuredAccessor & ~Escapable,
  AssociatedValue: StructuredDecodable
>: StructuredAccessor, ~Escapable {

  var isMutable: Bool { base.isMutable }

  func initializeValue(to value: sending AssociatedValue) async throws {
    try await base.initializeValue(to: `case`.initializer(value))
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing AssociatedValue, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    let accessor = `case`.accessor
    return try await base.accessValue(applying: delta) { value, delta in
      guard let value = accessor(value) else {
        throw EnumerationCodingError.valueHasUnexpectedCase
      }
      return try await apply(value, delta)
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout AssociatedValue, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    let initializer = `case`.initializer
    let accessor = `case`.accessor
    return try await base.mutateValue(applying: delta) { value, delta in
      guard var associatedValue = accessor(value) else {
        throw EnumerationCodingError.valueHasUnexpectedCase
      }
      defer { value = initializer(associatedValue) }
      return try await apply(&associatedValue, delta)
    }
  }

  @_lifetime(copy base)
  init(case: StructuredEnumerationCase<Base.Value, AssociatedValue>, base: consuming Base) {
    self.case = `case`
    self.base = base
  }
  let `case`: StructuredEnumerationCase<Base.Value, AssociatedValue>
  var base: Base
}

// MARK: - Errors

private enum EnumerationCodingError: Error {
  case noProperties
  case unknownCase(String)
  case discriminatorNotFound
  case invalidDiscriminator(observed: String, expected: String)
  case moreThanOneProperty
  case valueHasUnexpectedCase
  case unknownKind(JavaScriptObjectNotation.DecodingStream.ValueKind)
  case unknownRawValue(String)
  case noMatchingCase
}
