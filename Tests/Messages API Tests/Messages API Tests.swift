import SchemaCodingTestSupport
import Testing

@testable import MessagesAPI

@Suite("Messages API")
struct ToolTests {

  @Test
  func testEncoding() throws {
    let message = Message(
      role: .user,
      content: [
        .text(text: "Text"),
        .image(
          source: .base64(
            mediaType: .png,
            data: ""
          )
        ),
      ]
    )

    try test(
      message,
      encodesAs: #"""
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "Text"
            },
            {
              "type": "image",
              "source": {
                "type": "base64",
                "media_type": "image\/png",
                "data": ""
              }
            }
          ]
        }
        """#
    )
  }
}
