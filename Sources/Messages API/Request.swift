public import StructuredCoding

@APICodable
public struct Request<each Tool: StructuredCodable> {

  public init(messages: [Message], tools: repeat each Tool) {
    self.messages = messages
    self.tools = (repeat each tools)
  }

  public let messages: [Message]

  public let tools: (repeat each Tool)

}

// MARK: - Messages

@APICodable
public struct Message: Sendable {

  public init(role: MessageRole, content: [ContentBlock]) {
    self.role = role
    self.content = content
  }

  public let role: MessageRole

  public let content: [ContentBlock]

}

public enum MessageRole: String, CaseIterable, StructuredEnumeration, Sendable {
  case user, assistant
}

@APICodable
public enum ContentBlock: Sendable {
  case text(text: String)
  case image(source: ImageSource)

  @APICodable
  public enum ImageSource: Sendable {

    @APICodable(style: .wrapper)
    public struct Base64MediaType: Sendable {
      public static var png: Self { Self(stringValue: "image/png") }

      let stringValue: String
    }

    case base64(
      mediaType: Base64MediaType,
      data: String,
      cacheControl: CacheControl? = nil
    )
  }

}

// MARK: - Prompt Caching

@APICodable
public enum CacheControl: Sendable {

  case ephemeral(
    ttl: TimeToLive? = nil
  )

  @APICodable(style: .wrapper)
  public struct TimeToLive: Sendable {
    public static var fiveMinutes: Self { Self(stringValue: "5m") }
    public static var oneHour: Self { Self(stringValue: "1h") }
    let stringValue: String
  }

}
