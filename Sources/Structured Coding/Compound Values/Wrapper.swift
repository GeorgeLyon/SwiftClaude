private import JavaScriptObjectNotation

// MARK: - Definition

/// A single-value wrapper: a struct that codes as its one stored value, with
/// no object container around it. A media-type wrapper around a `String`
/// encodes as `"image/png"`, not `{"stringValue":"image/png"}`.
///
/// The requirements deliberately mirror `StructuredObject`'s (with the
/// property pack collapsed to a single required property), so
/// `@StructuredCodable(style: .wrapper)` reuses the object code generation
/// unchanged. Wrappers are *not* objects, though: they never code as JSON
/// objects, so they cannot stand in positions that require one — most notably
/// as an internally-tagged enumeration payload, which needs properties for
/// the discriminator to live alongside.
public protocol StructuredWrapper: StructuredCodable {

  associatedtype StructuredObjectProperties
  static func properties() -> StructuredObjectProperties

  associatedtype ObjectDecoderValues
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self

}

// MARK: - Schema

extension StructuredWrapper {

  /// A wrapper's schema is its wrapped value's schema; there is no structure
  /// of the wrapper's own to describe. `typeDescription` is the wrapper's own
  /// `@StructuredCodable(description:)`, prepended the way use-site
  /// descriptions are.
  public static func _schema<Definition>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where StructuredObjectProperties == StructuredObjectProperty<Self, Definition> {
    properties().schema.prependDescription(typeDescription)
  }

}

// MARK: - Encoding

extension StructuredWrapper {

  /// Defaults don't change a value's coded representation, and a wrapper has
  /// no object to omit an optional from, so encoding is always the stored
  /// value's own — hence `PropertyValue` (`String?` for an optional wrapper),
  /// not `CodingValue` (which drops the optionality an object property would
  /// express through omission).
  public func encode<Definition>(
    to encoder: inout StructuredEncoder
  ) throws
  where
    StructuredObjectProperties == StructuredObjectProperty<Self, Definition>,
    Definition.PropertyValue: StructuredEncodable
  {
    try Self.properties().taggedKeyPath.accessValue(on: self).encode(to: &encoder)
  }

}

// MARK: - Decoding

extension StructuredWrapper {

  /// Mirrors the per-property logic in `StructuredObject`'s
  /// `initialValueForDecoding`: the definition supplies the wrapped value's
  /// initial value (adjusted for whether the wrapper's key path can later be
  /// written through), and the wrapper is constructed around it. A
  /// `var`-backed `String` wrapper is seeded around the empty string and
  /// streams; a `let`-backed one stays unobservable until the value is
  /// complete; a constant wrapper is its declared value from the start.
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
    from decoder: inout StructuredDecoder,
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
      /// The wrapper was seeded, so the value decodes through the wrapper's
      /// key path — the same accessor object properties stream through. The
      /// definition supplies the shape-specific semantics: re-seeding a
      /// default-initialized `var` before streaming, or buffering a constant
      /// and returning it as the payload that `validate` compares.
      let validationPayload = try await property.definition.decodeValue(
        from: &decoder,
        in: context,
        using: KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
      )
      try await property.definition.validate(
        validationPayload,
        using: KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
      )
    } else {
      /// The value cannot decode in place, so it decodes to the side and the
      /// wrapper is constructed around it once complete. Validation runs
      /// against the scratch accessor — the constructed wrapper's property
      /// holds the same value.
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
          from: &decoder,
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

/// Specializations for wrappers whose stored value is optional-cored —
/// `Definition.PropertyValue == Definition.CodingValue?` characterizes the
/// optional definition and any defaulting wrapper around it.
///
/// The definition machinery expresses `nil` by *omitting the property from
/// the enclosing object*, a concept with no top-level analogue — so an
/// optional-cored wrapper codes through its stored value's own conformance
/// instead: `Optional`'s `{}` / `{"value":…}` form. Encoding needs no
/// specialization (it is already `PropertyValue`-driven); the schema and the
/// decoding side do.
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
    from decoder: inout StructuredDecoder,
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
        from: &decoder,
        in: context,
        using: KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
      )
    } else {
      let value = try await Definition.PropertyValue.decode(from: &decoder, in: context)
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

/// The argument vocabulary for `@StructuredCodable(style: .wrapper)`. Purely
/// a macro-argument marker — wrapper-ness is a conformance, not a runtime
/// style — but the argument must still typecheck, which is what this type
/// provides.
public struct StructuredWrapperStyle: Sendable {

  public static var wrapper: Self { Self() }

}
