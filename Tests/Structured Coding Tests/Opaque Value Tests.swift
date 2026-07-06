import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

@Suite("Opaque Value")
struct OpaqueValueTests {

  /// `OpaqueValue` captures the decoded JSON verbatim and replays it on encode,
  /// so a decode → encode round trip must reproduce the input byte-for-byte.
  /// (`OpaqueValue` is neither constructible from outside the JSON module nor
  /// `Equatable`, so the round trip is verified by re-encoding.)
  private func expectRoundTrips(
    _ json: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let decoded: OpaqueValue = try IncrementalDecoder().decode(from: Array(json.utf8)) { stream in
      try await stream.withDecoder { decoder in
        try await OpaqueValue.decode(from: &decoder, in: StructuredDecodingContext())
      }
    }
    var encoder = StructuredEncoder()
    try decoded.encode(to: &encoder)
    #expect(encoder.stringValue == json, sourceLocation: sourceLocation)
  }

  @Test func roundTripsString() throws { try expectRoundTrips(#""hello""#) }
  @Test func roundTripsNumber() throws { try expectRoundTrips("42") }
  @Test func roundTripsNegativeDecimal() throws { try expectRoundTrips("-3.14") }
  @Test func roundTripsBool() throws { try expectRoundTrips("true") }
  @Test func roundTripsNull() throws { try expectRoundTrips("null") }
  @Test func roundTripsEmptyObject() throws { try expectRoundTrips("{}") }
  @Test func roundTripsArray() throws { try expectRoundTrips(#"[1,"two",true,null]"#) }

  @Test func roundTripsNestedObject() throws {
    try expectRoundTrips(#"{"first":{"type":"string"},"nested":{"a":[1,2,3]}}"#)
  }

  /// The motivating use: an arbitrary sub-schema captured and replayed unchanged.
  @Test func roundTripsSchemaShape() throws {
    try expectRoundTrips(#"{"properties":{"x":{"type":"integer"}},"required":["x"]}"#)
  }

  /// The opaque value is its own ("any") schema — an empty schema.
  @Test func schemaEncodesAsAny() throws {
    try test(OpaqueValue.schema(description: nil), encodesAs: "{}")
  }

}
