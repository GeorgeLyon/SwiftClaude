import Foundation
import Testing

@testable import ClaudeClient

@Suite
private struct AnthropicEnumTests {

  @Test
  func testDecoding() throws {
    let decoder = JSONDecoder()
    func decode(_ string: String) throws -> TestEnum {
      try decoder.decode(
        AnthropicEnum<TestEnum>.self,
        from: Data(string.utf8)
      ).wrappedValue
    }

    #expect(
      try decode(
        """
        {
          "type": "content_block_start",
          "id": "12345"
        }
        """
      ) == .contentBlockStart(.init(id: "12345"))
    )

    #expect(
      try decode(
        """
        {
          "type": "content_block_delta",
          "text": "delta text"
        }
        """
      ) == .contentBlockDelta(.init(text: "delta text"))
    )

    #expect(
      try decode(
        """
        {
          "type": "content_block_stop",
          "index": 3
        }
        """
      ) == .contentBlockStop(.init(index: 3))
    )

    #expect(
      try decode(
        """
        {
          "type": "message_stop"
        }
        """
      ) == .messageStop
    )

  }
}

/// Test enum representing various cases of associated value patterns
private enum TestEnum: Equatable, Decodable {
  struct ContentBlockStart: Equatable, Decodable {
    let id: String
  }
  case contentBlockStart(ContentBlockStart)

  struct ContentBlockDelta: Equatable, Decodable {
    let text: String
  }
  case contentBlockDelta(ContentBlockDelta)

  struct ContentBlockStop: Equatable, Decodable {
    let index: Int
  }
  case contentBlockStop(ContentBlockStop)

  case messageStop
}
