import MessagesAPI
import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// `ToolInputEnvelope` is an ordinary generated object — its schema and
/// decoding are the generic object machinery's — and it composes with an
/// action's public typed `invoke`: the flow the dispatch round will follow
/// (decode the complete envelope value from the tool-use JSON, then invoke
/// with `envelope.input` — no deferred-invocation machinery involved).
@Suite("Tool Input Envelope")
struct ToolInputEnvelopeTests {

  /// The envelope's schema is exactly what `ToolDefinition` publishes for a
  /// non-object-input tool.
  @Test func envelopeSchemaEncodesAsObject() throws {
    var encoder = StructuredEncoder()
    try ToolInputEnvelope<Int>.schema.encode(to: &encoder)
    #expect(
      encoder.stringValue
        == #"{"properties":{"input":{"type":"integer"}},"required":["input"]}"#
    )
  }

  @Test func envelopeDecodesFromWireJSON() throws {
    let envelope: ToolInputEnvelope<Int> = try decode(#"{"input": 21}"#)
    #expect(envelope.input == 21)
  }

  /// A malformed envelope fails through the generic object-decode errors —
  /// missing required property, unknown property — not bespoke envelope
  /// cases.
  @Test func malformedEnvelopesThrowObjectDecodeErrors() {
    #expect(throws: (any Error).self) {
      let _: ToolInputEnvelope<Int> = try decode("21")
    }
    #expect(throws: (any Error).self) {
      let _: ToolInputEnvelope<Int> = try decode("{}")
    }
    #expect(throws: (any Error).self) {
      let _: ToolInputEnvelope<Int> = try decode(#"{"value": 21}"#)
    }
    #expect(throws: (any Error).self) {
      let _: ToolInputEnvelope<Int> = try decode(#"{"input": 21, "extra": 1}"#)
    }
  }

  /// Pins the future dispatch flow: decode the complete envelope value,
  /// then call the original action's public typed `invoke` with
  /// `envelope.input`.
  @Test func decodedEnvelopeComposesWithTypedInvoke() throws {
    let action = StructuredAction(
      name: "double",
      invoke: { (value: Int) in value * 2 }
    )
    let envelope: ToolInputEnvelope<Int> = try decode(#"{"input": 21}"#)
    #expect(action.invoke(with: envelope.input) == 42)
  }

}

// MARK: - Helpers

/// Decodes a complete JSON document into a value, standing in for the public
/// decode-from-JSON-text entry point the dispatch round will add as general
/// library surface.
private func decode<Value: StructuredDecodable>(_ json: String) throws -> Value {
  var jsonDecoder = JavaScriptObjectNotation.Decoder()
  return try jsonDecoder.decode(from: Array(json.utf8)) { stream in
    let value = try await stream.withDecoder { decoder in
      try await Value.decode(from: &decoder, in: StructuredDecodingContext())
    }
    try await stream.readTrailingWhitespace()
    return value
  }
}
