import Foundation
import Testing

@testable import Claude

@Test
func userMessageTextConcatenation() throws {
  let userMessage: UserMessage = "A\("1")B\("2")C\("3")"
  let requestContent = try userMessage.messageContent
    .messagesRequestMessageContent(
      for: .claude35Sonnet20241022,
      imagePreprocessingMode: .recommended(quality: 1)
    )
  let encoder = JSONEncoder()
  let data = try encoder.encode(requestContent)
  #expect(String(decoding: data, as: UTF8.self) == "\"A1B2C3\"")
}
