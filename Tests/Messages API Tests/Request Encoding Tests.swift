import MessagesAPI
import StructuredCoding
import Testing

/// Verifies the ported Messages API types encode to the Anthropic wire
/// format: `snake_case` keys, internally-tagged content blocks with a
/// `"type"` discriminator, wrapper values as bare strings, and `nil`
/// optionals omitted.
@Suite("Messages API Encoding")
struct MessagesAPIEncodingTests {

  @Test func encodesTextMessage() throws {
    try #expect(
      encode(Message(role: .user, content: [.text(text: "Hello, world")]))
        == #"{"role":"user","content":[{"type":"text","text":"Hello, world"}]}"#
    )
  }

  @Test func encodesAssistantRole() throws {
    try #expect(
      encode(Message(role: .assistant, content: [.text(text: "Hi!")]))
        == #"{"role":"assistant","content":[{"type":"text","text":"Hi!"}]}"#
    )
  }

  /// `cacheControl` defaults to `nil` and is omitted from the encoded object.
  @Test func encodesImageContent() throws {
    try #expect(
      encode(
        Message(
          role: .user,
          content: [.image(source: .base64(mediaType: .png, data: "iVBORw0KGgo="))]
        )
      )
        == #"{"role":"user","content":[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"iVBORw0KGgo="}}]}"#
    )
  }

  @Test func encodesImageContentWithCacheControl() throws {
    try #expect(
      encode(
        ContentBlock.image(
          source: .base64(
            mediaType: .png,
            data: "iVBORw0KGgo=",
            cacheControl: .ephemeral(ttl: .fiveMinutes)
          )
        )
      )
        == #"{"type":"image","source":{"type":"base64","media_type":"image/png","data":"iVBORw0KGgo=","cache_control":{"type":"ephemeral","ttl":"5m"}}}"#
    )
  }

  @Test func encodesMultipleContentBlocks() throws {
    try #expect(
      encode(
        Message(
          role: .user,
          content: [
            .text(text: "What is in this image?"),
            .image(source: .base64(mediaType: .png, data: "iVBORw0KGgo=")),
          ]
        )
      )
        == #"{"role":"user","content":[{"type":"text","text":"What is in this image?"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"iVBORw0KGgo="}}]}"#
    )
  }

  // MARK: - Requests

  /// `Request` is generic over a parameter pack of tools, so its conformance
  /// is generated with `.variadicGenerics` compatibility; encoding a value
  /// instantiates the property metadata that the default key-path emission
  /// crashes on at runtime.
  @Test func encodesRequestWithTools() throws {
    try #expect(
      encode(
        Request(
          messages: [Message(role: .user, content: [.text(text: "Hello, world")])],
          tools: Calculator(precision: 2), WebSearch(maxResults: 5)
        )
      )
        == #"{"messages":[{"role":"user","content":[{"type":"text","text":"Hello, world"}]}],"tools":[{"precision":2},{"max_results":5}]}"#
    )
  }

  /// An empty tool pack encodes as an empty `tools` array.
  @Test func encodesRequestWithoutTools() throws {
    try #expect(
      encode(Request(messages: [Message(role: .user, content: [.text(text: "Hello, world")])]))
        == #"{"messages":[{"role":"user","content":[{"type":"text","text":"Hello, world"}]}],"tools":[]}"#
    )
  }

  // MARK: - Cache Control

  /// A `nil` time-to-live is omitted, leaving only the discriminator.
  @Test func encodesCacheControlWithoutTimeToLive() throws {
    try #expect(encode(CacheControl.ephemeral()) == #"{"type":"ephemeral"}"#)
  }

  @Test func encodesCacheControlTimeToLives() throws {
    try #expect(
      encode(CacheControl.ephemeral(ttl: .fiveMinutes)) == #"{"type":"ephemeral","ttl":"5m"}"#
    )
    try #expect(
      encode(CacheControl.ephemeral(ttl: .oneHour)) == #"{"type":"ephemeral","ttl":"1h"}"#
    )
  }

  // MARK: - Wrappers

  /// Wrapper values encode as bare strings, not single-property objects.
  @Test func encodesWrappersAsBareStrings() throws {
    try #expect(encode(ContentBlock.ImageSource.Base64MediaType.png) == #""image/png""#)
    try #expect(encode(CacheControl.TimeToLive.fiveMinutes) == #""5m""#)
    try #expect(encode(CacheControl.TimeToLive.oneHour) == #""1h""#)
  }

  // MARK: - Roles

  /// `MessageRole` is a raw-value enumeration: a bare JSON string.
  @Test func encodesRolesAsBareStrings() throws {
    try #expect(encode(MessageRole.user) == #""user""#)
    try #expect(encode(MessageRole.assistant) == #""assistant""#)
  }

}

// MARK: - Helpers

@APICodable
private struct Calculator {
  let precision: Int
}

@APICodable
private struct WebSearch {
  let maxResults: Int
}

private func encode<Value: StructuredEncodable>(_ value: Value) throws -> String {
  var encoder = StructuredEncoder()
  try value.encode(to: &encoder)
  return encoder.stringValue
}
