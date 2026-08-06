import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// End-to-end tests for the `@StructuredCodable` macro: unlike the expansion
/// tests in `Tests/Structured Coding Macros Tests` (which compare generated
/// source text), these apply the real macro to fixture types and round-trip
/// values through encoding and decoding.
@Suite("Structured Codable Macro Integration")
struct StructuredCodableMacroIntegrationTests {

  // MARK: - Objects

  @Test func pointRoundTrips() async throws {
    try #expect(encode(MacroPoint(x: 1, y: 2)) == #"{"x":1,"y":2}"#)
    try await test(#"{"x":1,"y":2}"#, decodesAs: MacroPoint(x: 1, y: 2))
  }

  /// Optional, constant, and default-initialized properties.
  @Test func profileRoundTrips() async throws {
    try #expect(
      encode(MacroProfile(name: "ada", nickname: nil, count: 5))
        == #"{"name":"ada","kind":"profile","count":5}"#
    )
    try await test(
      #"{"name":"ada","kind":"profile","count":5}"#,
      decodesAs: MacroProfile(name: "ada", nickname: nil, count: 5)
    )
  }

  @Test func profileEncodesPresentOptional() async throws {
    try #expect(
      encode(MacroProfile(name: "ada", nickname: "al", count: 10))
        == #"{"name":"ada","nickname":"al","kind":"profile","count":10}"#
    )
  }

  @Test func mismatchedConstantThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"name":"ada","kind":"other","count":5}"#,
        decodesAs: MacroProfile(name: "ada", nickname: nil, count: 5)
      )
    }
  }

  // MARK: - Enumerations (object-properties style)

  @Test func singleValueCaseRoundTrips() async throws {
    try #expect(encode(MacroEvent.text("hi")) == #"{"text":"hi"}"#)
    try await test(#"{"text":"hi"}"#, decodesAs: MacroEvent.text("hi"))
  }

  /// A value-less case is represented by `StructuredEmptyObject`.
  @Test func valuelessCaseRoundTrips() async throws {
    try #expect(encode(MacroEvent.ping) == #"{"ping":{}}"#)
    try await test(#"{"ping":{}}"#, decodesAs: MacroEvent.ping)
  }

  // MARK: - Enumerations (internally tagged)

  @Test func internallyTaggedObjectCaseRoundTrips() async throws {
    try #expect(
      encode(MacroMessage.note(MacroNote(body: "hi"))) == #"{"type":"note","body":"hi"}"#
    )
    try await test(
      #"{"type":"note","body":"hi"}"#,
      decodesAs: MacroMessage.note(MacroNote(body: "hi"))
    )
  }

  /// An all-labeled case is wrapped in a macro-synthesized `StructuredObject`.
  @Test func internallyTaggedLabeledCaseRoundTrips() async throws {
    try #expect(encode(MacroMessage.move(x: 1, y: 2)) == #"{"type":"move","x":1,"y":2}"#)
    try await test(#"{"type":"move","x":1,"y":2}"#, decodesAs: MacroMessage.move(x: 1, y: 2))
  }

  // MARK: - Typealiased Optionals

  /// The motivating case for type-resolved property definitions: the macro
  /// cannot see through `typealias MacroAliasedOptional = String?`, but the
  /// type system can — the aliased property codes with omission semantics
  /// exactly like a spelled-out `String?`.
  @Test func typealiasedOptionalPropertyOmitsNil() async throws {
    try #expect(
      encode(MacroAliasedProfile(name: "ada", nickname: nil)) == #"{"name":"ada"}"#
    )
    try #expect(
      encode(MacroAliasedProfile(name: "ada", nickname: "al"))
        == #"{"name":"ada","nickname":"al"}"#
    )
    try await test(
      #"{"name":"ada"}"#,
      decodesAs: MacroAliasedProfile(name: "ada", nickname: nil)
    )
    try await test(
      #"{"name":"ada","nickname":"al"}"#,
      decodesAs: MacroAliasedProfile(name: "ada", nickname: "al")
    )
  }

  /// Likewise for wrappers: a typealiased optional wrapped value selects the
  /// optional-cored wrapper specialization.
  @Test func typealiasedOptionalWrapperCodesByOptionalConformance() async throws {
    try #expect(encode(MacroAliasedMaybe(name: "ada")) == #"{"value":"ada"}"#)
    try #expect(encode(MacroAliasedMaybe(name: nil)) == #"{}"#)
    try await test(#"{}"#, decodesAs: MacroAliasedMaybe(name: nil))
    try await test(#"{"value":"ada"}"#, decodesAs: MacroAliasedMaybe(name: "ada"))
  }

  // MARK: - Wrappers

  /// A `style: .wrapper` struct codes as its bare stored value.
  @Test func wrapperRoundTrips() async throws {
    try #expect(encode(MacroMediaType(stringValue: "image/png")) == #""image/png""#)
    try await test(#""image/png""#, decodesAs: MacroMediaType(stringValue: "image/png"))
  }

  /// A wrapper's schema is its wrapped value's schema, with the type's own
  /// description prepended.
  @Test func wrapperSchemaIsWrappedValueSchema() async throws {
    try await test(MacroMediaType.schema, encodesAs: #"{"type":"string"}"#)
    try await test(
      MacroDescribedMediaType.schema,
      encodesAs: #"{"description":"A MIME media type","type":"string"}"#
    )
  }

  /// An optional wrapped value has no enclosing object to omit a `nil` from,
  /// so it codes by `Optional`'s own conformance.
  @Test func optionalWrapperCodesByOptionalConformance() async throws {
    try #expect(encode(MacroMaybeName(name: "ada")) == #"{"value":"ada"}"#)
    try #expect(encode(MacroMaybeName(name: nil)) == #"{}"#)
    try await test(#"{"value":"ada"}"#, decodesAs: MacroMaybeName(name: "ada"))
    try await test(#"{}"#, decodesAs: MacroMaybeName(name: nil))
  }

  /// A `var` default on a wrapped value is a construction-time convenience
  /// with no coding role: the decoded value always wins.
  @Test func defaultedVarWrapperRoundTrips() async throws {
    try #expect(encode(MacroTag()) == #""untagged""#)
    try await test(#""tagged""#, decodesAs: MacroTag(text: "tagged"))
  }

  /// A constant wrapped value (`let` with a default) decodes only its
  /// declared value — anything else fails validation, exactly like a constant
  /// object property.
  @Test func constantWrapperValidatesDecodedValue() async throws {
    try #expect(encode(MacroFixedTag()) == #""fixed""#)
    try await test(#""fixed""#, decodesAs: MacroFixedTag())
    await #expect(throws: (any Error).self) {
      try await test(#""other""#, decodesAs: MacroFixedTag())
    }
  }

  /// A wrapper used as an object property codes as its bare value in place.
  @Test func wrapperObjectPropertyCodesInPlace() async throws {
    try #expect(
      encode(MacroAttachment(media: MacroMediaType(stringValue: "image/png")))
        == #"{"media":"image/png"}"#
    )
    try await test(
      #"{"media":"image/png"}"#,
      decodesAs: MacroAttachment(media: MacroMediaType(stringValue: "image/png"))
    )
  }

  // MARK: - Key Conversion

  @Test func snakeCaseKeysRoundTrip() async throws {
    try #expect(
      encode(MacroUser(firstName: "Ada", lastName: "Lovelace"))
        == #"{"first_name":"Ada","last_name":"Lovelace"}"#
    )
    try await test(
      #"{"first_name":"Ada","last_name":"Lovelace"}"#,
      decodesAs: MacroUser(firstName: "Ada", lastName: "Lovelace")
    )
  }

  // MARK: - Member Annotations

  /// `@StructuredProperty` and `@StructuredCase` attach descriptions without
  /// affecting the coded representation.
  @Test func annotatedMembersRoundTrip() async throws {
    try #expect(encode(MacroAnnotatedObject(x: 1)) == #"{"x":1}"#)
    try await test(#"{"x":1}"#, decodesAs: MacroAnnotatedObject(x: 1))

    try #expect(encode(MacroAnnotatedEnum.text("hi")) == #"{"text":"hi"}"#)
    try await test(#"{"text":"hi"}"#, decodesAs: MacroAnnotatedEnum.text("hi"))
  }

  /// The attached descriptions surface in the generated schema: the
  /// `@StructuredCodable` description on the type's own schema, the
  /// `@StructuredProperty` description on the property's schema, and the
  /// `@StructuredCase` description on the case's slot in the
  /// object-properties schema.
  @Test func annotatedMembersDescribeSchema() async throws {
    try await test(
      MacroAnnotatedObject.schema,
      encodesAs:
        #"{"description":"An object with annotated members","properties":{"x":{"description":"The horizontal coordinate","type":"integer"}},"required":["x"]}"#
    )
    try await test(
      MacroAnnotatedEnum.schema,
      encodesAs:
        #"{"description":"An enumeration with annotated cases","properties":{"text":{"description":"A text message","type":"string"}},"maxProperties":1}"#
    )
  }

  /// A description prepended by a use site lands before the type's own,
  /// separated by a blank line.
  @Test func useSiteAndTypeDescriptionsConcatenate() async throws {
    try await test(
      MacroAnnotatedObject.schema.prependDescription("As used here"),
      encodesAs:
        #"{"description":"As used here\n\nAn object with annotated members","properties":{"x":{"description":"The horizontal coordinate","type":"integer"}},"required":["x"]}"#
    )
  }

  /// The same concatenation applies when the use-site description comes from
  /// a `@StructuredProperty` annotation on a property of the described type.
  @Test func propertyAndTypeDescriptionsConcatenate() async throws {
    try await test(
      MacroAnnotatedContainer.schema,
      encodesAs:
        #"{"properties":{"object":{"description":"The annotated object\n\nAn object with annotated members","properties":{"x":{"description":"The horizontal coordinate","type":"integer"}},"required":["x"]}},"required":["object"]}"#
    )
  }

  // MARK: - Object Representable

  /// The macro marks types whose every encoded instance is a JSON object:
  /// objects, and the object-properties and internally-tagged enumeration
  /// styles (the latter's payloads are constrained to `StructuredObject`, so
  /// the discriminator always lives inside an object).
  @Test func objectEncodedTypesAreMarkedObjectRepresentable() {
    #expect(MacroPoint.self is any StructuredObjectRepresentable.Type)
    #expect(MacroEvent.self is any StructuredObjectRepresentable.Type)
    #expect(MacroMessage.self is any StructuredObjectRepresentable.Type)
  }

  /// Type-discriminated enumerations encode bare payloads, wrappers encode
  /// their stored value, and raw-value enumerations encode scalars — none
  /// carry the marker, so a tool definition envelopes them when they stand
  /// as a single action's input.
  @Test func nonObjectEncodedTypesAreNotMarkedObjectRepresentable() {
    #expect(!(MacroValue.self is any StructuredObjectRepresentable.Type))
    #expect(!(MacroMediaType.self is any StructuredObjectRepresentable.Type))
    #expect(!(MacroColor.self is any StructuredObjectRepresentable.Type))
    #expect(!(String.self is any StructuredObjectRepresentable.Type))
  }

  // MARK: - Classes

  /// A (non-final) class codes exactly like the equivalent struct; `decode`
  /// constructs it through the macro-generated `required init(from:)`.
  @Test func classRoundTrips() async throws {
    try #expect(
      encode(MacroCounter(id: 1, label: "a", note: nil, count: 5))
        == #"{"id":1,"label":"a","kind":"counter","count":5}"#
    )
    try await test(
      #"{"id":1,"label":"a","kind":"counter","count":5}"#,
      decodesAs: MacroCounter(id: 1, label: "a", note: nil, count: 5)
    )
  }

  /// The optional property may be omitted; the constant and default-initialized
  /// properties behave exactly as on a struct.
  @Test func classOptionalAndDefaultedProperties() async throws {
    try #expect(
      encode(MacroCounter(id: 1, label: "a", note: "n", count: 10))
        == #"{"id":1,"label":"a","note":"n","kind":"counter","count":10}"#
    )
    try await test(
      [#"{"id":1,"la"#, #"bel":"a","kind":"count"#, #"er","count":5}"#],
      decodesAs: MacroCounter(id: 1, label: "a", note: nil, count: 5)
    )
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"id":1,"label":"a","kind":"other","count":5}"#,
        decodesAs: MacroCounter(id: 1, label: "a", note: nil, count: 5)
      )
    }
  }

  /// A class whose every stored property is a reference-writable `var` is
  /// constructed up front and streamed in place.
  @Test func classStreamsInPlace() async throws {
    try await test(
      #"{"name":"abc"}"#,
      decodesAs: MacroReferenceObject(name: "abc")
    )
    try await test(
      #"{"name":"ab"#,
      decodesAs: .partial(MacroReferenceObject(name: "a"))
    )
  }

}

// MARK: - Fixtures

@StructuredCodable
private struct MacroPoint: Equatable, Sendable {
  let x: Int
  let y: Int
}

@StructuredCodable
private struct MacroProfile: Equatable, Sendable {
  var name: String
  var nickname: String?
  let kind: String = "profile"
  var count: Int = 10
}

@StructuredCodable
private enum MacroEvent: Equatable, Sendable {
  case text(String)
  case ping
}

@StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "type"))
private enum MacroMessage: Equatable, Sendable {
  case note(MacroNote)
  case move(x: Int, y: Int)
}

@StructuredCodable
private struct MacroNote: Equatable, Sendable {
  var body: String
}

@StructuredCodable(style: .typeDiscriminated)
private enum MacroValue: Equatable, Sendable {
  case number(Int)
  case text(String)
}

private enum MacroColor: String, CaseIterable, StructuredEnumeration, Sendable {
  case red, green
}

private typealias MacroAliasedOptional = String?

@StructuredCodable
private struct MacroAliasedProfile: Equatable, Sendable {
  var name: String
  var nickname: MacroAliasedOptional
}

@StructuredCodable(style: .wrapper)
private struct MacroAliasedMaybe: Equatable, Sendable {
  let name: MacroAliasedOptional
}

@StructuredCodable(style: .wrapper)
private struct MacroMediaType: Equatable, Sendable {
  let stringValue: String
}

@StructuredCodable(description: "A MIME media type", style: .wrapper)
private struct MacroDescribedMediaType: Equatable, Sendable {
  let stringValue: String
}

@StructuredCodable(style: .wrapper)
private struct MacroMaybeName: Equatable, Sendable {
  let name: String?
}

@StructuredCodable(style: .wrapper)
private struct MacroTag: Equatable, Sendable {
  var text: String = "untagged"
}

@StructuredCodable(style: .wrapper)
private struct MacroFixedTag: Equatable, Sendable {
  let text: String = "fixed"
}

@StructuredCodable
private struct MacroAttachment: Equatable, Sendable {
  var media: MacroMediaType
}

/// `var` rather than `let` properties: two immutable mutation-streamed (`String`)
/// properties hit a known decoding issue (see
/// `MidStreamInitializationTests.twoUnavailableMutationStreamedPropertiesInitializeMidStream`)
/// that is unrelated to the macro.
@StructuredCodable(keyConversionStrategy: .convertToSnakeCase)
private struct MacroUser: Equatable, Sendable {
  var firstName: String
  var lastName: String
}

@StructuredCodable(description: "An object with annotated members")
private struct MacroAnnotatedObject: Equatable, Sendable {
  @StructuredProperty(description: "The horizontal coordinate")
  let x: Int
}

@StructuredCodable(description: "An enumeration with annotated cases")
private enum MacroAnnotatedEnum: Equatable, Sendable {
  @StructuredCase(description: "A text message")
  case text(String)
}

@StructuredCodable
private struct MacroAnnotatedContainer: Equatable, Sendable {
  @StructuredProperty(description: "The annotated object")
  var object: MacroAnnotatedObject
}

/// Mirrors `MacroProfile`'s property kinds on a deliberately non-final class:
/// `decode`'s `Self` return is covariant, so construction goes through the
/// macro-generated `required init(from:)` in the class body. The `let id`
/// property has no initial value, exercising the buffered decode branch.
@StructuredCodable
private final class MacroCounter: Equatable, @unchecked Sendable {
  let id: Int
  var label: String
  var note: String?
  let kind: String = "counter"
  var count: Int = 10

  init(id: Int, label: String, note: String?, count: Int) {
    self.id = id
    self.label = label
    self.note = note
    self.count = count
  }

  static func == (lhs: MacroCounter, rhs: MacroCounter) -> Bool {
    lhs.id == rhs.id && lhs.label == rhs.label && lhs.note == rhs.note
      && lhs.count == rhs.count
  }
}

/// Every stored property is a reference-writable `var`, so the instance is
/// created up front (through the required initializer, seeded with streaming
/// initial values) and decoded values stream into place.
@StructuredCodable
private final class MacroReferenceObject: Equatable, @unchecked Sendable {
  var name: String

  init(name: String) {
    self.name = name
  }

  static func == (lhs: MacroReferenceObject, rhs: MacroReferenceObject) -> Bool {
    lhs.name == rhs.name
  }
}

// MARK: - Helper

private func encode<Value: StructuredEncodable>(_ value: Value) throws -> String {
  var stream = StructuredEncodingStream()
  try value.encode(to: &stream)
  return stream.stringValue
}
