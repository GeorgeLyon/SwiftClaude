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

  @Test func pointRoundTrips() throws {
    try #expect(encode(MacroPoint(x: 1, y: 2)) == #"{"x":1,"y":2}"#)
    try test(#"{"x":1,"y":2}"#, decodesAs: MacroPoint(x: 1, y: 2))
  }

  /// Optional, constant, and default-initialized properties.
  @Test func profileRoundTrips() throws {
    try #expect(
      encode(MacroProfile(name: "ada", nickname: nil, count: 5))
        == #"{"name":"ada","kind":"profile","count":5}"#
    )
    try test(
      #"{"name":"ada","kind":"profile","count":5}"#,
      decodesAs: MacroProfile(name: "ada", nickname: nil, count: 5)
    )
  }

  @Test func profileEncodesPresentOptional() throws {
    try #expect(
      encode(MacroProfile(name: "ada", nickname: "al", count: 10))
        == #"{"name":"ada","nickname":"al","kind":"profile","count":10}"#
    )
  }

  @Test func mismatchedConstantThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"name":"ada","kind":"other","count":5}"#,
        decodesAs: MacroProfile(name: "ada", nickname: nil, count: 5)
      )
    }
  }

  // MARK: - Enumerations (object-properties style)

  @Test func singleValueCaseRoundTrips() throws {
    try #expect(encode(MacroEvent.text("hi")) == #"{"text":"hi"}"#)
    try test(#"{"text":"hi"}"#, decodesAs: MacroEvent.text("hi"))
  }

  /// A value-less case is represented by `StructuredEmptyObject`.
  @Test func valuelessCaseRoundTrips() throws {
    try #expect(encode(MacroEvent.ping) == #"{"ping":{}}"#)
    try test(#"{"ping":{}}"#, decodesAs: MacroEvent.ping)
  }

  // MARK: - Enumerations (internally tagged)

  @Test func internallyTaggedObjectCaseRoundTrips() throws {
    try #expect(
      encode(MacroMessage.note(MacroNote(body: "hi"))) == #"{"type":"note","body":"hi"}"#
    )
    try test(
      #"{"type":"note","body":"hi"}"#,
      decodesAs: MacroMessage.note(MacroNote(body: "hi"))
    )
  }

  /// An all-labeled case is wrapped in a macro-synthesized `StructuredObject`.
  @Test func internallyTaggedLabeledCaseRoundTrips() throws {
    try #expect(encode(MacroMessage.move(x: 1, y: 2)) == #"{"type":"move","x":1,"y":2}"#)
    try test(#"{"type":"move","x":1,"y":2}"#, decodesAs: MacroMessage.move(x: 1, y: 2))
  }

  // MARK: - Key Conversion

  @Test func snakeCaseKeysRoundTrip() throws {
    try #expect(
      encode(MacroUser(firstName: "Ada", lastName: "Lovelace"))
        == #"{"first_name":"Ada","last_name":"Lovelace"}"#
    )
    try test(
      #"{"first_name":"Ada","last_name":"Lovelace"}"#,
      decodesAs: MacroUser(firstName: "Ada", lastName: "Lovelace")
    )
  }

  // MARK: - Member Annotations

  /// `@StructuredProperty` and `@StructuredCase` attach descriptions without
  /// affecting the coded representation.
  @Test func annotatedMembersRoundTrip() throws {
    try #expect(encode(MacroAnnotatedObject(x: 1)) == #"{"x":1}"#)
    try test(#"{"x":1}"#, decodesAs: MacroAnnotatedObject(x: 1))

    try #expect(encode(MacroAnnotatedEnum.text("hi")) == #"{"text":"hi"}"#)
    try test(#"{"text":"hi"}"#, decodesAs: MacroAnnotatedEnum.text("hi"))
  }

  /// The attached descriptions surface in the generated schema: on the
  /// property's schema for `@StructuredProperty`, and on the case's slot in
  /// the object-properties schema for `@StructuredCase`.
  @Test func annotatedMembersDescribeSchema() throws {
    try test(
      MacroAnnotatedObject.schema(description: nil),
      encodesAs:
        #"{"properties":{"x":{"description":"The horizontal coordinate","type":"integer"}},"required":["x"]}"#
    )
    try test(
      MacroAnnotatedEnum.schema(description: nil),
      encodesAs:
        #"{"properties":{"text":{"description":"A text message","type":"string"}},"maxProperties":1}"#
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

// MARK: - Helper

private func encode<Value: StructuredEncodable>(_ value: Value) throws -> String {
  var encoder = StructuredEncoder()
  try value.encode(to: &encoder)
  return encoder.stringValue
}
