private import JavaScriptObjectNotation

// MARK: - Definition

/// A single-value wrapper: a struct that codes as its one stored value, with
/// no object container around it. A media-type wrapper around a `String`
/// encodes as `"image/png"`, not `{"stringValue":"image/png"}`.
public protocol StructuredWrapper: StructuredCodable {

  associatedtype StructuredObjectProperties
  static func properties() -> StructuredObjectProperties

  associatedtype ObjectDecoderValues
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self

}

// MARK: - Schema

extension StructuredWrapper {

  public static func _schema<Definition>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where StructuredObjectProperties == StructuredObjectProperty<Self, Definition> {
    properties().schema.prependDescription(typeDescription)
  }

}

// MARK: - Encoding

extension StructuredWrapper {

  /// Encodes the stored `PropertyValue`, not `CodingValue`: a wrapper has no
  /// enclosing object to omit an optional from, so switching to
  /// `CodingValue` would silently change the wire format of optional
  /// wrappers.
  public func encode<Definition>(
    to stream: inout StructuredEncodingStream
  ) throws
  where
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    Definition.PropertyValue: StructuredEncodable
  {
    try Self.properties().taggedKeyPath.accessValue(on: self).encode(to: &stream)
  }

}

// MARK: - Decoding

extension StructuredWrapper {

  public static func initialValueForDecoding<Definition>(
    isMutable isBaseMutable: Bool
  ) -> sending Self?
  where
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    ObjectDecoderValues == Definition.ObjectDecoderValue
  {
    let property = properties()
    let isMutable =
      switch property.taggedKeyPath {
      case .getOnly, .getOnlyClosure:
        false
      case .writable:
        isBaseMutable
      case .referenceWritable:
        true
      }
    switch property.definition.initialValueForDecoding(isMutable: isMutable).kind {
    case .none:
      return nil
    case .propertyValue(let value):
      return decode(
        from: StructuredObjectDecoder(values: property.definition.objectDecoderValue(from: value))
      )
    case .objectDecoderValue(let value):
      return decode(from: StructuredObjectDecoder(values: value))
    }
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    Definition
  >(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    ObjectDecoderValues == Definition.ObjectDecoderValue
  {
    let property = properties()
    if initialValueForDecoding(isMutable: accessor.isMutable) != nil {
      let validationPayload = try await property.definition.decodeValue(
        from: &stream,
        in: context,
        using: KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
      )
      try await property.definition.validate(
        validationPayload,
        using: KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
      )
    } else {
      let value = try await withSendingAccessor(
        of: Definition.PropertyValue.self,
        in: context
      ) { scratch in
        switch property.definition.initialValueForDecoding(isMutable: true).kind {
        case .propertyValue(let initialValue):
          try await scratch.initializeValue(to: initialValue)
        case .objectDecoderValue, .none:
          break
        }
        let validationPayload = try await property.definition.decodeValue(
          from: &stream,
          in: context,
          using: scratch
        )
        try await property.definition.validate(validationPayload, using: scratch)
      }
      try await accessor.initializeValue(
        to: decode(
          from: StructuredObjectDecoder(
            values: property.definition.objectDecoderValue(from: value)
          )
        )
      )
    }
  }

}

// MARK: - Optional Values

/// Specializations for wrappers whose stored value is optional: `nil` has no
/// enclosing object to be omitted from, so an optional-cored wrapper codes
/// through `Optional`'s own `{}` / `{"value":…}` form.
extension StructuredWrapper {

  public static func _schema<Definition>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    Definition.PropertyValue == Definition.CodingValue?
  {
    Definition.PropertyValue.schema.prependDescription(typeDescription)
  }

  public static func initialValueForDecoding<Definition>(
    isMutable isBaseMutable: Bool
  ) -> sending Self?
  where
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    Definition.PropertyValue == Definition.CodingValue?,
    ObjectDecoderValues == Definition.ObjectDecoderValue
  {
    let property = properties()
    let isMutable =
      switch property.taggedKeyPath {
      case .getOnly, .getOnlyClosure:
        false
      case .writable:
        isBaseMutable
      case .referenceWritable:
        true
      }
    guard let value = Definition.PropertyValue.initialValueForDecoding(isMutable: isMutable)
    else {
      return nil
    }
    return decode(
      from: StructuredObjectDecoder(values: property.definition.objectDecoderValue(from: value))
    )
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    Definition
  >(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    Definition.PropertyValue == Definition.CodingValue?,
    ObjectDecoderValues == Definition.ObjectDecoderValue
  {
    let property = properties()
    if initialValueForDecoding(isMutable: accessor.isMutable) != nil {
      try await Definition.PropertyValue.decode(
        from: &stream,
        in: context,
        using: KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
      )
    } else {
      let value = try await Definition.PropertyValue.decode(from: &stream, in: context)
      try await accessor.initializeValue(
        to: decode(
          from: StructuredObjectDecoder(
            values: property.definition.objectDecoderValue(from: value)
          )
        )
      )
    }
  }

}

// MARK: - Style

/// The argument type for `@StructuredCodable(style: .wrapper)`.
public struct StructuredWrapperStyle: Sendable {

  public static var wrapper: Self { Self() }

}
