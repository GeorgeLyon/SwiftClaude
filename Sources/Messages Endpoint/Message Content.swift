public import ClaudeClient

public import struct Foundation.Data

extension ClaudeClient.MessagesEndpoint.Request.Message {

  /// - note:
  ///   `Message.Content` is used for things other than messages, such as the system prompt.
  ///   I couldn't come up with a more general name though so it remains `Message.Content` for now.
  public struct Content: Encodable, ExpressibleByStringInterpolation, ExpressibleByArrayLiteral {

    public init() {
      self.trailingText = []
      self.blocks = []
    }

    public init(_ string: String) {
      self.init()
      append(string)
    }

    public init(stringLiteral value: String) {
      self.init(value)
    }

    public init(_ block: Block) {
      self.trailingText = []
      self.blocks = [block]
    }

    public init(arrayLiteral blocks: Block...) {
      self.trailingText = []
      self.blocks = blocks
    }

    public init(_ blocks: [Block]) {
      self.trailingText = []
      self.blocks = blocks
    }

    public init(_ blocks: Block...) {
      self.trailingText = []
      self.blocks = blocks
    }

    public init(_ cacheBreakpoint: CacheBreakpoint) {
      self.trailingText = []
      self.blocks = [.cacheBreakpoint(cacheBreakpoint)]
    }

    public mutating func reserveCapacity(_ capacity: Int) {
      /// Overprovision both arrays since it is cheap
      trailingText.reserveCapacity(capacity)
      blocks.reserveCapacity(capacity)
    }

    public mutating func append(
      _ text: String,
      cacheBreakpoint: CacheBreakpoint? = nil
    ) {
      trailingText.append(text)
      if let cacheBreakpoint {
        append(cacheBreakpoint)
      }
    }

    public mutating func append(
      _ block: Block,
      cacheBreakpoint: CacheBreakpoint? = nil
    ) {
      processTrailingText()
      blocks.append(block)
      if let cacheBreakpoint {
        append(cacheBreakpoint)
      }
    }

    public mutating func append(
      _ cacheBreakpoint: CacheBreakpoint
    ) {
      processTrailingText()
      blocks.append(.cacheBreakpoint(cacheBreakpoint))
    }

    public static func += (lhs: inout Self, rhs: Self) {
      if rhs.blocks.isEmpty {
        lhs.trailingText.append(contentsOf: rhs.trailingText)
      } else {
        lhs.processTrailingText()
        lhs.blocks.append(contentsOf: rhs.blocks)
        lhs.trailingText.append(contentsOf: rhs.trailingText)
      }
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
      var result = lhs
      result += rhs
      return result
    }

    private mutating func processTrailingText() {
      let text = trailingText.joined()
      /// Empty text content blocks are rejected by the API
      guard !text.isEmpty else { return }
      blocks.append(.text(text))
      trailingText.removeAll(keepingCapacity: true)
    }

    public func encode(to encoder: any Encoder) throws {
      if blocks.isEmpty, !trailingText.isEmpty {
        /// If there is only trailing text, encode as a string
        try trailingText.joined().encode(to: encoder)
        return
      } else {
        /// Otherwise encode as content blocks

        let encodableBlocks:
          ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray<AnyEncodable>
        do {
          var mutableSelf = self
          mutableSelf.processTrailingText()
          encodableBlocks = ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray(
            elements: mutableSelf.blocks
              .map(\.cacheableComponentArrayElement)
          )
        }
        try encodableBlocks.encode(to: encoder)
      }
    }

    var containsCacheBreakpoints: Bool {
      blocks.map(\.cacheableComponentArrayElement).contains(where: \.isCacheBreakpoint)
    }

    private var trailingText: [String]
    private var blocks: [Block]

    public typealias CacheBreakpoint = ClaudeClient.MessagesEndpoint.Request.CacheBreakpoint

  }

}

// MARK: - Blocks

extension ClaudeClient.MessagesEndpoint.Request.Message.Content {

  public struct Block {

    public static func text(
      _ text: String
    ) -> Block {
      Block(
        Text(
          text: text
        )
      )
    }
    public static func toolUse(
      id: ClaudeClient.MessagesEndpoint.ToolUse.ID,
      name: String,
      input: any Encodable
    ) -> Block {
      Block(
        ToolUse(
          id: id,
          name: name,
          input: AnyEncodable(input)
        )
      )
    }
    public static func toolResult(
      id: ClaudeClient.MessagesEndpoint.ToolUse.ID,
      content: ToolResultContent?,
      isError: Bool? = nil
    ) -> Block {
      Block(
        ToolResult(
          toolUseId: id,
          content: content,
          isError: isError
        )
      )
    }
    public static func image(
      mediaType: MediaType,
      data: Data
    ) -> Block {
      Block(
        Image(
          source: Image.Source(
            mediaType: mediaType,
            data: Image.Source.Base64EncodedData(rawData: data)
          )
        )
      )
    }

    public typealias CacheBreakpoint = ClaudeClient.MessagesEndpoint.Request.CacheBreakpoint
    public static func cacheBreakpoint(_ cacheBreakpoint: CacheBreakpoint) -> Block {
      Block(cacheBreakpoint)
    }

    public struct MediaType: Encodable {
      public static var jpeg: Self { Self(rawValue: "image/jpeg") }
      public static var png: Self { Self(rawValue: "image/png") }
      public static var gif: Self { Self(rawValue: "image/gif") }
      public static var webp: Self { Self(rawValue: "image/webp") }

      public func encode(to encoder: any Encoder) throws {
        try rawValue.encode(to: encoder)
      }

      private let rawValue: String
    }

    /// `tool_result` content is currently the same as `user` message content.
    /// Use a typealias so that we can reuse `Content` manipulation logic.
    public typealias ToolResultContent = ClaudeClient.MessagesEndpoint.Request.Message.Content

    private struct Text: Encodable {
      private let type = "text"

      let text: String
    }
    private struct ToolUse: Encodable {
      private let type = "tool_use"

      let id: ClaudeClient.MessagesEndpoint.ToolUse.ID
      let name: String
      let input: AnyEncodable
    }
    private struct ToolResult: Encodable {
      private let type = "tool_result"

      let toolUseId: ClaudeClient.MessagesEndpoint.ToolUse.ID
      let content: ToolResultContent?
      let isError: Bool?
    }
    private struct Image: Encodable {
      private let type = "image"

      struct Source: Encodable {
        private let type = "base64"

        let mediaType: MediaType

        struct Base64EncodedData: Encodable {
          let rawData: Data
          func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawData.base64EncodedString())
          }
        }
        let data: Base64EncodedData
      }
      let source: Source
    }

    private init(_ component: any Encodable) {
      cacheableComponentArrayElement = .component(AnyEncodable(component))
    }
    private init(_ cacheBreakpoint: CacheBreakpoint) {
      cacheableComponentArrayElement = .cacheBreakpoint(cacheBreakpoint)
    }

    fileprivate let cacheableComponentArrayElement:
      ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray<AnyEncodable>.Element
  }

}

// MARK: - List Comprehensions

extension Sequence where Element == ClaudeClient.MessagesEndpoint.Request.Message.Content {

  public func joined() -> Element {
    reduce(into: Element(), +=)
  }

}
