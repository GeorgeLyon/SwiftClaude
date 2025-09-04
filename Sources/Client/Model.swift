public import ClaudeCommon

/// https://docs.anthropic.com/en/docs/about-claude/models
extension ClaudeClient.Model {

  /// The default model may change without notice
  /// If using a specific model is important, specify it explicitly.
  public static var `default`: Self {
    .claudeOpus4120250805
  }

  // MARK: - Opus Models

  public static var claudeOpus4120250805: Self {
    Self(
      id: "claude-opus-4-1-20250805",
      maxOutputTokens: 8192,
      vision: .anthropicDefault
    )
  }

  public static var claudeOpus420250514: Self {
    Self(
      id: "claude-opus-4-20250514",
      maxOutputTokens: 8192,
      vision: .anthropicDefault
    )
  }

  // MARK: - Sonnet Models

  public static var claudeSonnet420250514: Self {
    Self(
      id: "claude-sonnet-4-20250514",
      maxOutputTokens: 8192,
      vision: .anthropicDefault
    )
  }

  public static var claude37Sonnet20250219: Self {
    Self(
      id: "claude-3-7-sonnet-20250219",
      maxOutputTokens: 8192,
      vision: .anthropicDefault
    )
  }

  // MARK: - Haiku Models

  public static var claude35haiku20241022: Self {
    Self(
      id: "claude-3-5-haiku-20241022",
      maxOutputTokens: 8192,
      vision: .anthropicDefault
    )
  }

  public static var claude3haiku20240307: Self {
    Self(
      id: "claude-3-haiku-20240307",
      maxOutputTokens: 4096,
      vision: .anthropicDefault
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
