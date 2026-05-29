/// https://docs.anthropic.com/en/docs/about-claude/models
extension ClaudeClient.Model {

  /// The default model may change without notice
  /// If using a specific model is important, specify it explicitly.
  public static var `default`: Self {
    .claude35Sonnet20241022
  }

  public static var claude35haiku20241022: Self {
    Self(
      id: "claude-3-5-haiku-20241022",
      maxOutputTokens: 8192,
      vision: .unavailable
    )
  }
  public static var claude35Sonnet20241022: Self {
    Self(
      id: "claude-3-5-sonnet-20241022",
      maxOutputTokens: 8192,
      vision: .standard
    )
  }
  public static var claude3Opust20240229: Self {
    Self(
      id: "claude-3-opus-20240229",
      maxOutputTokens: 4096,
      vision: .standard
    )
  }
  public static var claude3haiku20240307: Self {
    Self(
      id: "claude-3-haiku-20240307",
      maxOutputTokens: 4096,
      vision: .standard
    )
  }

}

extension ClaudeClient {

  public struct Model {

    public let id: ID
    public let maxOutputTokens: Int
    public let vision: Vision

    public init(
      id: ID,
      maxOutputTokens: Int,
      vision: Vision
    ) {
      self.id = id
      self.maxOutputTokens = maxOutputTokens
      self.vision = vision
    }

    public struct ID: TypedID, Sendable, Codable, ExpressibleByStringInterpolation {

      public init(untypedValue: UntypedID) {
        self.untypedValue = untypedValue
      }
      public let untypedValue: UntypedID

    }

  }

}
