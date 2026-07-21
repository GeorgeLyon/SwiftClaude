import JavaScriptObjectNotation
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
        ),
        pretty: true
      )
        == #"""
        {
          "role": "user",
          "content": [
            {
              "type": "image",
              "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": "iVBORw0KGgo="
              }
            }
          ]
        }
        """#
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
        ),
        pretty: true
      )
        == #"""
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/png",
            "data": "iVBORw0KGgo=",
            "cache_control": {
              "type": "ephemeral",
              "ttl": "5m"
            }
          }
        }
        """#
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
        ),
        pretty: true
      )
        == #"""
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "What is in this image?"
            },
            {
              "type": "image",
              "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": "iVBORw0KGgo="
              }
            }
          ]
        }
        """#
    )
  }

  // MARK: - Tool Definitions

  /// `ToolDefinition.init` classifies each tool statically: a composed
  /// multi-action tool's keyed enumeration is a top-level object by
  /// construction, so it encodes as the tool's `input_schema` directly.
  /// This also pins the classification hazard: a composed action matches
  /// the enveloped initializer's shape too, and only its `@_disfavoredOverload`
  /// makes the group overload win — were it chosen, this test would see an
  /// envelope schema instead of the enumeration.
  @Test func encodesGroupToolDefinitionDirectly() throws {
    try #expect(
      encode(ToolDefinition(Calculator()))
        == #"{"name":"Calculator","description":"Does math","input_schema":{"properties":{"add":{"properties":{"amount":{"type":"integer"}},"required":["amount"]},"parity":{"properties":{"of":{"type":"integer"}},"required":["of"]}},"maxProperties":1}}"#
    )
  }

  /// A single action whose input is `StructuredObjectRepresentable` publishes
  /// its raw schema directly; a tool without a description omits the key.
  @Test func encodesObjectInputToolDefinitionDirectly() throws {
    try #expect(
      encode(ToolDefinition(WebSearch()))
        == #"{"name":"WebSearch","input_schema":{"properties":{"query":{"type":"string"}},"required":["query"]}}"#
    )
  }

  /// A single action with any other input is mapped onto `ToolInputEnvelope`,
  /// so its schema is the envelope object's `{"input": ...}` — the Anthropic
  /// API requires `input_schema` to be a top-level object.
  @Test func encodesScalarInputToolDefinitionEnveloped() throws {
    try #expect(
      encode(ToolDefinition(Doubler()))
        == #"{"name":"Doubler","description":"Doubles numbers","input_schema":{"properties":{"input":{"type":"integer"}},"required":["input"]}}"#
    )
  }

  // MARK: - Requests

  /// Tools encode as Anthropic tool definitions — `name`, `description`,
  /// `input_schema` — from the `ToolDefinition` values wrapped at the call
  /// site. A tool without a description omits the key.
  ///
  /// `Request` is generic over a parameter pack of tool input schemas, so its
  /// conformance is generated with `.variadicGenerics` compatibility;
  /// encoding a value instantiates the property metadata that the default
  /// key-path emission crashes on at runtime.
  @Test func encodesRequestWithTools() throws {
    try #expect(
      encode(
        Request(
          model: .claudeOpus4_8,
          maxTokens: 1024,
          messages: [Message(role: .user, content: [.text(text: "Hello, world")])],
          tools: ToolDefinition(Calculator()), ToolDefinition(WebSearch())
        ),
        pretty: true
      )
        == #"""
        {
          "model": "claude-opus-4-8",
          "max_tokens": 1024,
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": "Hello, world"
                }
              ]
            }
          ],
          "tools": [
            {
              "name": "Calculator",
              "description": "Does math",
              "input_schema": {
                "properties": {
                  "add": {
                    "properties": {
                      "amount": {
                        "type": "integer"
                      }
                    },
                    "required": [
                      "amount"
                    ]
                  },
                  "parity": {
                    "properties": {
                      "of": {
                        "type": "integer"
                      }
                    },
                    "required": [
                      "of"
                    ]
                  }
                },
                "maxProperties": 1
              }
            },
            {
              "name": "WebSearch",
              "input_schema": {
                "properties": {
                  "query": {
                    "type": "string"
                  }
                },
                "required": [
                  "query"
                ]
              }
            }
          ]
        }
        """#
    )
  }

  /// A single action whose input schema is not an object surfaces through
  /// the request with its `{"input": ...}` envelope.
  @Test func encodesEnvelopedScalarToolInputSchema() throws {
    try #expect(
      encode(
        Request(
          model: .claudeSonnet5,
          maxTokens: 512,
          messages: [Message(role: .user, content: [.text(text: "21")])],
          tools: ToolDefinition(Doubler())
        ),
        pretty: true
      )
        == #"""
        {
          "model": "claude-sonnet-5",
          "max_tokens": 512,
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": "21"
                }
              ]
            }
          ],
          "tools": [
            {
              "name": "Doubler",
              "description": "Doubles numbers",
              "input_schema": {
                "properties": {
                  "input": {
                    "type": "integer"
                  }
                },
                "required": [
                  "input"
                ]
              }
            }
          ]
        }
        """#
    )
  }

  /// An empty tool pack encodes as an empty `tools` array. `model` and
  /// `maxTokens` lead the object, with `maxTokens` rendered as `max_tokens`.
  @Test func encodesRequestWithoutTools() throws {
    try #expect(
      encode(
        Request(
          model: .claudeOpus4_8,
          maxTokens: 1024,
          messages: [Message(role: .user, content: [.text(text: "Hello, world")])]
        )
      )
        == #"{"model":"claude-opus-4-8","max_tokens":1024,"messages":[{"role":"user","content":[{"type":"text","text":"Hello, world"}]}],"tools":[]}"#
    )
  }

  /// A model built from a raw identifier encodes as that bare string, matching
  /// the static accessors.
  @Test func encodesModelIdentifiers() throws {
    try #expect(encode(Model.claudeOpus4_8) == #""claude-opus-4-8""#)
    try #expect(encode(Model.claudeFable5) == #""claude-fable-5""#)
    try #expect(encode(Model("claude-opus-4-5")) == #""claude-opus-4-5""#)
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

@StructuredTool(description: "Does math")
private struct Calculator {
  @StructuredAction
  func add(amount: Int) -> Int {
    amount
  }

  @StructuredAction
  func parity(of value: Int) -> Bool {
    value.isMultiple(of: 2)
  }
}

@StructuredTool
private struct WebSearch {
  @StructuredAction
  func search(query: String) -> String {
    query
  }
}

@StructuredTool(description: "Doubles numbers")
private struct Doubler {
  @StructuredAction
  func double(_ value: Int) -> Int {
    value * 2
  }
}

private func encode<Value: StructuredEncodable>(
  _ value: Value,
  pretty: Bool = false
) throws -> String {
  var encoder = StructuredEncoder(options: pretty ? .prettyPrint : [])
  try value.encode(to: &encoder)
  return encoder.stringValue
}
