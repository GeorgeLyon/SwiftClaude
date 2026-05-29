import Foundation
import Testing

@testable import Claude

@Test
func userMessageTextConcatenation() throws {
  let userMessage: Claude.ConversationUserMessage<Conversation> = "A\("1")B\("2")C\("3")"
  let requestContent =
    try userMessage
    .messagesRequestMessageContent(
      for: .claude35Sonnet20241022,
      imagePreprocessingMode: .recommended(quality: 1),
      renderImage: { _ in
        fatalError()
      }
    )
  let encoder = JSONEncoder()
  let data = try encoder.encode(requestContent)
  #expect(String(decoding: data, as: UTF8.self) == "\"A1B2C3\"")
}

private struct Conversation: Claude.Conversation {
  var messages: [Message]
}
