public import SchemaCoding

// @APICodable
public struct Request<each Tool: SchemaCoding.SchemaCodable> {

  public let messages: [Message]

  public let tools: (repeat each Tool)

}

// MARK: - Messages

@APICodable
public struct Message {

  public let role: MessageRole

  public let content: [ContentBlock]

}

public enum MessageRole: String, CaseIterable {
  case user, assistant
}

@APICodable
public enum ContentBlock {
  case text(text: String)
  case image(source: ImageSource)

  @APICodable()
  public enum ImageSource {

    @APICodable(style: .wrapper)
    public struct Base64MediaType {
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
public enum CacheControl {

  case ephemeral(
    ttl: TimeToLive? = nil
  )

  @APICodable(style: .wrapper)
  public struct TimeToLive {
    public static var fiveMinutes: Self { Self(stringValue: "5m") }
    public static var oneHour: Self { Self(stringValue: "1h") }
    let stringValue: String
  }

}
