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

// MARK: - Schema

/// The schema of an object-properties enumeration: a single object schema with
/// one property per case — named for the case, valued with that case's
/// associated-value schema. No case property is required (the value carries
/// exactly one of them, which `maxProperties` expresses) —
/// `{"properties":{"<case>":<schema>, …},"maxProperties":1}`.
@StructuredCodable(compatibilityMode: [.variadicGenerics, .omitSchema])
public struct StructuredObjectPropertiesEnumerationSchema<
  Base: StructuredEnumeration,
  each AssociatedValue: StructuredDecodable
>: StructuredCodingSchema
where
  Base.CodingStyle == StructuredEnumerationCodingStyleObjectProperties,
  Base.Cases == (repeat StructuredEnumerationCase<Base, each AssociatedValue>)
{

  public init(description: String?) {
    self.description = description
    self.properties = Properties()
  }

  private let description: String?

  public struct Properties: StructuredCodable {

    /// Like `StructuredObjectSchema.Properties`, this hand-written conformance
    /// uses the concrete `StructuredAnySchema`; see
    /// `StructuredCodingCompatibilityMode.omitSchema`.
    public typealias Schema = StructuredAnySchema

    private typealias CaseSchemas = StructuredTuple<repeat (each AssociatedValue).Schema>

    /// One associated-value schema per case, in declaration order; the case
    /// names come from `Base.cases()` rather than being stored.
    private let caseSchemas: CaseSchemas

    init() {
      self.caseSchemas = StructuredTuple(repeat (each AssociatedValue).Schema())
    }

    public func encode(to encoder: inout StructuredEncoder) throws {
      let cases = Base.cases()
      try encoder.stream.encodeObject { objectEncoder in
        for (`case`, schema) in repeat (each cases, each caseSchemas.values) {
          try objectEncoder.encodeProperty(`case`.name.stringValue) { stream in
            try stream.withEncoder { encoder in
              try schema.encode(to: &encoder)
            }
          }
        }
      }
    }

    public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
      nil
    }

    /// Decoding is hand-written for the same reason as
    /// `StructuredObjectSchema.Properties`: the case properties are
    /// dynamically named, and the `StructuredObject` extension witnesses abort
    /// the task allocator for genuinely pack-expanded conformances.
    public static func decode<Accessor: StructuredAccessor & ~Escapable>(
      from decoder: inout StructuredDecoder,
      in context: borrowing StructuredDecodingContext,
      using accessor: Accessor
    ) async throws where Accessor.Value == Self {
      try await context.withArena { arena in
        let cases = Base.cases()
        let stateRefs =
          (repeat arena.push(
            CaseSchemaDecodingState<(each AssociatedValue).Schema>.pending
          ).unsafePointer)

        try await decoder.stream.decodeObject { objectDecoder in
          for (`case`, stateRef) in repeat (each cases, each stateRefs) {
            guard !objectDecoder.isAtEnd else {
              throw EnumerationSchemaDecodingError.caseNotFound(`case`.name.stringValue)
            }
            try await objectDecoder.decodeProperty(
              decodeValue: { name, stream in
                /// Case schemas are decoded in declaration order — the order
                /// `encode` writes them.
                guard name == `case`.name.stringValue else {
                  throw EnumerationSchemaDecodingError.unknownCase(name)
                }
                try await stream.withDecoder { decoder in
                  try await stateRef.pointee.decode(from: &decoder, in: context)
                }
              }
            )
          }
          if !objectDecoder.isAtEnd {
            try await objectDecoder.decodeProperty(
              decodeValue: { name, _ in
                throw EnumerationSchemaDecodingError.unknownCase(name)
              }
            )
          }
        }

        try await accessor.initializeValue(
          to: Self(repeat try (each stateRefs).pointee.takeDecodedValue())
        )
      }
    }

    private init(_ caseSchemas: repeat (each AssociatedValue).Schema) {
      self.caseSchemas = StructuredTuple(repeat each caseSchemas)
    }

  }
  private let properties: Properties

  /// The value is a single-property object: the one property names the case.
  /// No case property is required, so the length constraint is the schema's
  /// only structural hint.
  private let maxProperties: Int = 1

}

/// The decoding state of a single case's associated-value schema in
/// `StructuredObjectPropertiesEnumerationSchema.Properties`' hand-written
/// `decode`.
private enum CaseSchemaDecodingState<Value: StructuredDecodable>: ~Copyable {

  /// The case schema has not been decoded yet.
  case pending

  /// The case schema has been fully decoded.
  case decoded(Sending<Value>)

  mutating func decode(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext
  ) async throws {
    let value = try await Value.decode(from: &decoder, in: context)
    self = .decoded(Sending(value))
  }

  /// Moves the decoded schema out, leaving the state `pending`.
  mutating func takeDecodedValue() throws -> sending Value {
    switch consume self {
    case .pending:
      self = .pending
      throw EnumerationSchemaDecodingError.caseSchemaNotDecoded
    case .decoded(let value):
      self = .pending
      return value.send()
    }
  }

}

private enum EnumerationSchemaDecodingError: Error {
  case caseNotFound(String)
  case unknownCase(String)
  case caseSchemaNotDecoded
}

// MARK: - Coding Style

public protocol StructuredEnumerationCodingStyle: Sendable {

}

extension StructuredEnumerationCodingStyle
where Self == StructuredEnumerationCodingStyleObjectProperties {
  /// The default style: each case is encoded as a single-property object whose
  /// property name is the case name.
  public static var objectProperties: Self { Self() }
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
