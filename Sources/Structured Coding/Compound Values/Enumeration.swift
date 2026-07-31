private import JavaScriptObjectNotation

public import struct Foundation.Decimal

public protocol StructuredEnumeration: StructuredCodable {

  associatedtype CodingStyle: StructuredEnumerationCodingStyle =
    StructuredEnumerationCodingStyleObjectProperties
  static var codingConfiguration: StructuredEnumerationCodingConfiguration<CodingStyle> { get }

  associatedtype Cases
  static func cases() -> Cases

}

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public static var codingConfiguration: StructuredEnumerationCodingConfiguration<CodingStyle> {
    StructuredEnumerationCodingConfiguration(style: CodingStyle())
  }

}

extension StructuredEnumeration where Self: RawRepresentable & CaseIterable {

  public static var codingConfiguration:
    StructuredEnumerationCodingConfiguration<StructuredEnumerationCodingStyleRawValue>
  {
    StructuredEnumerationCodingConfiguration(style: .rawValue)
  }

  /// Raw-value enumerations carry no per-case associated values, so there are no
  /// `StructuredEnumerationCase`s to enumerate; the case is determined by `init(rawValue:)`.
  /// `CaseIterable` is required so the schema can enumerate the raw values.
  public static func cases() { () }

}

// MARK: - Schema

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public static func _schema<each AssociatedValue: StructuredDecodable>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let cases = cases()
    return MetaSchema.object(
      description: typeDescription,
      maxProperties: 1,
      properties: repeat (
        (each cases).name,
        (each AssociatedValue).schema.prependDescription((each cases).description),
        false
      )
    )
  }

}

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleInternallyTagged {

  /// An internally-tagged value is one of its cases' objects with the
  /// discriminator property added, so the schema is a `oneOf` whose branches
  /// are the case object schemas, each with the discriminator spliced in as
  /// its first required property, pinned to the case's name.
  public static func _schema<each AssociatedValue: StructuredObject>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let discriminatorPropertyName = codingConfiguration.style.discriminatorPropertyName
    var branches: [MetaSchema.SchemaCodable] = []
    for `case` in repeat each cases() {
      branches.append(
        `case`.internallyTaggedBranchSchema(
          discriminatorPropertyName: discriminatorPropertyName
        )
      )
    }
    return MetaSchema.oneOf(
      description: typeDescription,
      subschemas: branches
    )
  }

}

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleTypeDiscriminated {

  public static func _schema<each AssociatedValue: StructuredDecodable>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let cases = cases()
    return MetaSchema.oneOf(
      description: typeDescription,
      subschemas: repeat (each AssociatedValue).schema.prependDescription((each cases).description)
    )
  }

}

extension StructuredEnumeration
where
  Self: RawRepresentable & CaseIterable,
  CodingStyle == StructuredEnumerationCodingStyleRawValue,
  RawValue: StructuredEncodable
{

  /// A raw-value enumeration's structural schema is the `enum` keyword listing
  /// every case's raw value in declaration order, which is why the style
  /// requires `CaseIterable`.
  public static func _schema(typeDescription: String? = nil) -> some StructuredCodingSchema {
    MetaSchema.enumeration(
      description: typeDescription,
      values: allCases.map(\.rawValue)
    )
  }

  /// `_schema` is non-generic for this style, so the extension can provide the
  /// witness directly — raw-value enumerations keep needing no boilerplate.
  public static var schema: some StructuredCodingSchema {
    _schema()
  }

}

// MARK: - Encoding

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public func encode<each AssociatedValue: StructuredEncodable>(
    to stream: inout StructuredEncodingStream
  ) throws
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let casesTuple = Self.cases()
    let cases = (repeat each casesTuple)
    try stream.json.encodeObject { objectEncoder in
      for `case` in repeat each cases {
        guard let associatedValue = `case`.accessor(self) else { continue }
        try objectEncoder.encodeProperty(`case`.name.stringValue) { stream in
          try stream.withStructuredEncodingStream { stream in
            try associatedValue.encode(to: &stream)
          }
        }
        return
      }
      throw EnumerationCodingError.noMatchingCase
    }
  }

}

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleInternallyTagged {

  public func encode<each AssociatedValue: StructuredObject>(
    to stream: inout StructuredEncodingStream
  ) throws
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let discriminatorPropertyName = Self.codingConfiguration.style.discriminatorPropertyName
    let casesTuple = Self.cases()
    let cases = (repeat each casesTuple)
    try stream.json.encodeObject { objectEncoder in
      try objectEncoder.withPropertiesEncoder { propertiesEncoder in
        for `case` in repeat each cases {
          guard let associatedValue = `case`.accessor(self) else { continue }
          let caseName = `case`.name.stringValue
          try propertiesEncoder.encodeProperty(named: discriminatorPropertyName) { stream in
            try caseName.encode(to: &stream)
          }
          try associatedValue.encodeProperties(to: &propertiesEncoder)
          return
        }
        throw EnumerationCodingError.noMatchingCase
      }
    }
  }

}

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleTypeDiscriminated {

  public func encode<each AssociatedValue: StructuredEncodable>(
    to stream: inout StructuredEncodingStream
  ) throws
  where Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>) {
    let casesTuple = Self.cases()
    let cases = (repeat each casesTuple)
    for `case` in repeat each cases {
      guard let associatedValue = `case`.accessor(self) else { continue }
      try associatedValue.encode(to: &stream)
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

  public func encode(to stream: inout StructuredEncodingStream) throws {
    try rawValue.encode(to: &stream)
  }

}

extension StructuredEnumeration
where
  Self: RawRepresentable,
  CodingStyle == StructuredEnumerationCodingStyleRawValue,
  RawValue: FixedWidthInteger & Sendable
{

  public func encode(to stream: inout StructuredEncodingStream) {
    stream.json.encode(rawValue)
  }

}

// MARK: - Decoding

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleObjectProperties {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each AssociatedValue
  >(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>)
  {
    try await stream.json.decodeObject { objectDecoder in
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

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleInternallyTagged {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each AssociatedValue: StructuredObject
  >(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>)
  {
    try await stream.json.decodeObject { objectDecoder in
      let discriminator = try await objectDecoder.peekObjectProperty(
        named: codingConfiguration.style.discriminatorPropertyName.stringValue,
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
              discriminatorPropertyName: codingConfiguration.style.discriminatorPropertyName,
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

extension StructuredEnumeration
where CodingStyle == StructuredEnumerationCodingStyleTypeDiscriminated {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each AssociatedValue
  >(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    Cases == (repeat StructuredEnumerationCase<Self, each AssociatedValue>)
  {
    let kind = try await stream.json.peekValueKind()
    for `case` in repeat each cases() {
      guard `case`.kind == kind else {
        continue
      }
      try await `case`.decode(from: &stream.json, in: context, using: accessor)
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
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let rawValue = try await stream.json.decodeString()
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
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let number = try await stream.json.decodeNumber()
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
  /// Carried into the case's slot in the enumeration's schema — the property
  /// schema in the object-properties style, the `oneOf` branch otherwise.
  let description: String?
  let accessor: @Sendable (Enumeration) -> AssociatedValue?
  let initializer: @Sendable (AssociatedValue) -> sending Enumeration

  fileprivate let kind: JavaScriptObjectNotation.DecodingStream.ValueKind?

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: nil)
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue == String {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: .string)
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue == Bool {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: .boolean)
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue: FixedWidthInteger {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: .number)
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue: BinaryFloatingPoint {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: .number)
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue == Decimal {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: .number)
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration
  ) where AssociatedValue: StructuredObject {
    self.init(
      name: name, description: description,
      accessor: accessor, initializer: initializer, kind: .object)
  }

  private init(
    name: StructuredCodingKey,
    description: String?,
    accessor: @escaping @Sendable (Enumeration) -> AssociatedValue?,
    initializer: @escaping @Sendable (AssociatedValue) -> sending Enumeration,
    kind: JavaScriptObjectNotation.DecodingStream.ValueKind?
  ) {
    self.name = name
    self.description = description
    self.accessor = accessor
    self.initializer = initializer
    self.kind = kind
  }

  fileprivate func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout DecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Enumeration {
    try await stream.withStructuredDecodingStream { stream in
      try await accessor.withCaseAccessor(for: self) { accessor in
        if let initialValue = AssociatedValue.initialValueForDecoding(
          isMutable: accessor.isMutable
        ) {
          try await accessor.initializeValue(to: initialValue)
        }
        try await AssociatedValue.decode(
          from: &stream,
          in: context,
          using: accessor
        )
      }
    }
  }

  fileprivate func internallyTaggedBranchSchema(
    discriminatorPropertyName: StructuredCodingKey
  ) -> MetaSchema.SchemaCodable where AssociatedValue: StructuredObject {
    MetaSchema.internallyTaggedBranch(
      discriminatorPropertyName: discriminatorPropertyName,
      caseName: name,
      caseSchema: AssociatedValue.schema.prependDescription(description)
    )
  }

  fileprivate func decodeProperties<Accessor: StructuredAccessor & ~Escapable>(
    discriminatorPropertyName: StructuredCodingKey,
    from propertiesDecoder: inout StructuredObjectPropertiesDecoder,
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
        from: &propertiesDecoder,
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
    from propertiesDecoder: inout StructuredObjectPropertiesDecoder
  ) -> DecodingState {
    propertiesDecoder.createCheckpoint()
  }
  func decodeAdditionalProperties(
    from propertiesDecoder: inout StructuredObjectPropertiesDecoder,
    with checkpoint: DecodingState
  ) async throws {
    try await propertiesDecoder.decodeIfNextPropertyNamed(
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

// MARK: - Coding Configuration

/// How a `StructuredEnumeration` codes: the style its cases collapse onto,
/// plus what its case payload objects synthesized by `@StructuredCodable` do
/// with undeclared properties. The behavior recorded here is the one the
/// macro propagates into every synthesized payload object; a case whose
/// single associated value is its own `StructuredObject` type keeps that
/// type's setting.
public struct StructuredEnumerationCodingConfiguration<
  Style: StructuredEnumerationCodingStyle
>: Sendable {

  public var style: Style
  public var undeclaredPropertyBehavior: StructuredUndeclaredPropertyBehavior

  public init(
    style: Style,
    undeclaredPropertyBehavior: StructuredUndeclaredPropertyBehavior = .reject
  ) {
    self.style = style
    self.undeclaredPropertyBehavior = undeclaredPropertyBehavior
  }

}

// MARK: - Coding Style

public protocol StructuredEnumerationCodingStyle: Sendable {}

extension StructuredEnumerationCodingStyle
where Self == StructuredEnumerationCodingStyleObjectProperties {
  public static var objectProperties: Self { Self() }
}

public struct StructuredEnumerationCodingStyleObjectProperties: StructuredEnumerationCodingStyle {
}

extension StructuredEnumerationCodingStyle
where Self == StructuredEnumerationCodingStyleInternallyTagged {
  public static func internallyTagged(discriminatorPropertyName: StructuredCodingKey) -> Self {
    Self(discriminatorPropertyName: discriminatorPropertyName)
  }
}

public struct StructuredEnumerationCodingStyleInternallyTagged: StructuredEnumerationCodingStyle {
  fileprivate init(discriminatorPropertyName: StructuredCodingKey) {
    self.discriminatorPropertyName = discriminatorPropertyName
  }
  fileprivate let discriminatorPropertyName: StructuredCodingKey
}

extension StructuredEnumerationCodingStyle
where Self == StructuredEnumerationCodingStyleTypeDiscriminated {
  public static var typeDiscriminated: Self { Self() }
}

public struct StructuredEnumerationCodingStyleTypeDiscriminated: StructuredEnumerationCodingStyle {
}

extension StructuredEnumerationCodingStyle where Self == StructuredEnumerationCodingStyleRawValue {
  static var rawValue: Self { Self() }
}

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
