import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// `undeclaredPropertyBehavior: .discard` on an enumeration applies to every
/// case's payload object, in both the object-properties and internally-tagged
/// styles: the macro propagates the setting into each synthesized payload
/// object (including the shared empty payload synthesized for value-less
/// cases). A case whose single associated value is its own object type keeps
/// that type's setting — the enumeration's does not leak into it.
@Suite("Undeclared Properties (Enumeration)")
struct UndeclaredPropertyEnumerationTests {

  // MARK: - Object-properties style

  @Test func discardsUnknownPayloadProperty() throws {
    try test(
      #"{"note":{"text":"hi","junk":1}}"#,
      decodesAs: LenientEvent.note(text: "hi")
    )
  }

  @Test func discardsUnknownPropertiesInEmptyCasePayload() throws {
    try test(
      #"{"ping":{"junk":true,"more":[1,2]}}"#,
      decodesAs: LenientEvent.ping
    )
  }

  @Test func emptyCaseStillDecodesFromEmptyPayload() throws {
    try test(
      #"{"ping":{}}"#,
      decodesAs: LenientEvent.ping
    )
  }

  /// The synthesized empty payload object encodes exactly like
  /// `StructuredEmptyObject` did.
  @Test func emptyCaseStillEncodesAsEmptyObject() throws {
    try test(
      LenientEvent.ping,
      encodesAs: #"{"ping":{}}"#
    )
  }

  /// The setting governs case *payloads*; the single-property wrapper object
  /// naming the case stays strict — a second property is structurally a
  /// different case, not an undeclared payload property.
  @Test func caseNamingObjectStaysStrict() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"note":{"text":"hi"},"extra":{}}"#,
        decodesAs: LenientEvent.note(text: "hi")
      )
    }
  }

  // MARK: - Internally-tagged style

  @Test func discardsUnknownPropertyAfterDiscriminator() throws {
    try test(
      #"{"kind":"circle","radius":1.5,"junk":"x"}"#,
      decodesAs: LenientShape.circle(radius: 1.5)
    )
  }

  @Test func discardsUnknownPropertyBeforeDiscriminator() throws {
    try test(
      #"{"junk":{},"kind":"circle","radius":1.5}"#,
      decodesAs: LenientShape.circle(radius: 1.5)
    )
  }

  @Test func discardsUnknownPropertiesInEmptyInternallyTaggedCase() throws {
    try test(
      #"{"kind":"ping","junk":1}"#,
      decodesAs: LenientShape.ping
    )
  }

  @Test func emptyInternallyTaggedCaseRoundTrips() throws {
    try test(
      LenientShape.ping,
      encodesAs: #"{"kind":"ping"}"#
    )
    try test(
      #"{"kind":"ping"}"#,
      decodesAs: LenientShape.ping
    )
  }

  /// A single-object case's payload keeps its own (default, rejecting)
  /// setting even though the enumeration discards.
  @Test func singleObjectCaseRespectsPayloadSetting() throws {
    try test(
      #"{"kind":"wrapped","value":1}"#,
      decodesAs: LenientShape.wrapped(StrictPayload(value: 1))
    )
    #expect(throws: (any Error).self) {
      try test(
        #"{"kind":"wrapped","value":1,"junk":2}"#,
        decodesAs: LenientShape.wrapped(StrictPayload(value: 1))
      )
    }
  }

  /// The converse: a rejecting enumeration with a discarding payload type —
  /// the payload's own setting still governs.
  @Test func discardingPayloadGovernsInRejectingEnumeration() throws {
    try test(
      #"{"kind":"lenient","text":"hi","junk":1}"#,
      decodesAs: StrictShape.lenient(LenientPayload(text: "hi"))
    )
  }

  @Test func rejectingEnumerationStillRejectsSynthesizedPayloads() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"kind":"boxed","width":1.0,"junk":2}"#,
        decodesAs: StrictShape.boxed(width: 1.0)
      )
    }
  }
}

// MARK: - Fixtures

/// Object-properties style with `.discard`: the synthesized `note` payload and
/// the shared empty payload both inherit the setting.
@StructuredCodable(undeclaredPropertyBehavior: .discard)
private enum LenientEvent: Equatable, Sendable {
  case note(text: String)
  case ping
}

/// Internally-tagged style with `.discard`; `wrapped`'s payload is its own
/// object type, whose (default, rejecting) setting is respected.
@StructuredCodable(
  style: .internallyTagged(discriminatorPropertyName: "kind"),
  undeclaredPropertyBehavior: .discard
)
private enum LenientShape: Equatable, Sendable {
  case circle(radius: Double)
  case ping
  case wrapped(StrictPayload)
}

/// Default behavior — rejects undeclared properties.
@StructuredCodable
private struct StrictPayload: Equatable, Sendable {
  var value: Int
}

/// A rejecting enumeration whose `lenient` case wraps a discarding object
/// type.
@StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "kind"))
private enum StrictShape: Equatable, Sendable {
  case lenient(LenientPayload)
  case boxed(width: Double)
}

@StructuredCodable(undeclaredPropertyBehavior: .discard)
private struct LenientPayload: Equatable, Sendable {
  var text: String
}
