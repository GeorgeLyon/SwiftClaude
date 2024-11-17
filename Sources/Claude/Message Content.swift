public import ClaudeClient
public import ClaudeMessagesEndpoint

#if canImport(UIKit)
  public import UIKit
#endif

#if canImport(AppKit)
  public import AppKit
#endif

extension Claude {

  /// The content of a message.
  /// This type can optionally apply recommended image processing, such as resizing large images
  /// - note:
  ///   `MessageContent` is used for things other than messages, such as the system prompt.
  ///   I couldn't come up with a more general name though so it remains `MessageContent` for now.
  public struct MessageContent {

    public init() {
      components = []
    }

    public init(
      _ component: Component
    ) {
      self.components = [component]
    }

    public init(
      _ components: [Component]
    ) {
      self.components = components
    }

    public mutating func append(
      contentsOf other: MessageContent
    ) {
      components.append(contentsOf: other.components)
    }

    public static func += (lhs: inout Self, rhs: Self) {
      lhs.components.append(contentsOf: rhs.components)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
      var result = lhs
      result.components.append(contentsOf: rhs.components)
      return result
    }

    public mutating func reserveCapacity(_ minimumCapacity: Int) {
      components.reserveCapacity(minimumCapacity)
    }

    public struct Component {

      public static func text(_ text: String) -> Self {
        Self(kind: .text(text))
      }

      public static func toolResult(
        id: ToolUse.ID,
        content: Claude.ToolInvocationResultContent?,
        isError: Bool? = nil
      ) -> Self {
        Self(
          kind: .toolResult(
            id: id,
            content: content?.messageContent,
            isError: isError
          )
        )
      }

      public static func image(
        _ image: Image
      ) -> Self {
        Self(kind: .image(image))
      }

      #if canImport(UIKit)
        public static func image(
          _ image: UIImage
        ) -> Self {
          Self(kind: .image(Claude.PlatformImage(image)))
        }
      #endif

      #if canImport(AppKit)
        public static func image(
          _ image: NSImage
        ) -> Self {
          Self(kind: .image(Claude.PlatformImage(image)))
        }
      #endif

      public static func cacheBreakpoint(_ cacheBreakpoint: Beta.CacheBreakpoint) -> Self {
        Self(kind: .cacheBreakpoint(cacheBreakpoint))
      }

      fileprivate enum Kind {
        case text(String)

        case toolUse(
          id: ToolUse.ID,
          name: String,
          input: any Encodable & Sendable
        )

        case toolResult(
          id: ToolUse.ID,
          content: MessageContent?,
          isError: Bool?
        )

        case image(Image)

        case cacheBreakpoint(Beta.CacheBreakpoint)

      }
      fileprivate let kind: Kind

      private init(kind: Kind) {
        self.kind = kind
      }
    }
    public var components: [Component]

    func messagesRequestMessageContent(
      for model: Model,
      imagePreprocessingMode: Image.PreprocessingMode
    ) throws -> sending ClaudeClient.MessagesEndpoint.Request.Message.Content {
      var content: ClaudeClient.MessagesEndpoint.Request.Message.Content = []
      for component in components {
        switch component.kind {
        case .text(let text):
          content.append(text)
        case let .toolUse(id, name, input):
          content.append(
            .toolUse(
              id: id,
              name: name,
              input: input
            )
          )
        case let .toolResult(id, resultContent, isError):
          content.append(
            .toolResult(
              id: id,
              content: try resultContent?.messagesRequestMessageContent(
                for: model,
                imagePreprocessingMode: imagePreprocessingMode
              ),
              isError: isError
            )
          )
        case .image(let image):
          let otherContent = try image.messagesRequestMessageContent(
            for: model,
            preprocessingMode: imagePreprocessingMode
          )
          content.append(contentsOf: otherContent)
          break
        case .cacheBreakpoint(let breakpoint):
          content.append(.cacheBreakpoint(breakpoint))
        }
      }
      return content

    }

  }

}

extension Sequence where Element == Claude.MessageContent {

  public func joined() -> Element {
    reduce(into: Element(), +=)
  }

}

// MARK: - Message Content Representable

extension Claude {

  public protocol ExpressibleByMessageContent: ExpressibleByStringInterpolation {

    init(messageContent: MessageContent)

  }

  public protocol MessageContentRepresentable: ExpressibleByMessageContent {

    var messageContent: MessageContent { get set }

  }

}

extension Claude.ExpressibleByMessageContent {

  public init(_ text: String) {
    self.init(messageContent: MessageContent([.text(text)]))
  }

}

extension Claude.MessageContentRepresentable {

  public mutating func append(_ text: String) {
    messageContent.components.append(.text(text))
  }

  public mutating func append(contentsOf other: Self) {
    messageContent.append(contentsOf: other.messageContent)
  }

  public static func += (lhs: inout Self, rhs: Self) {
    lhs.messageContent += rhs.messageContent
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    var result = lhs
    result += rhs
    return result
  }

}

// MARK: - Expressible By String Interpolation

extension Claude.ExpressibleByMessageContent {

  public init(stringLiteral value: String) {
    self.init(messageContent: MessageContent([.text(value)]))
  }

  public init(stringInterpolation: Claude.MessageContentStringInterpolation<Self>) {
    self.init(messageContent: stringInterpolation.messageContent)
  }

  public typealias MessageContent = Claude.MessageContent

}

extension Claude {

  public struct MessageContentStringInterpolation<Component>: StringInterpolationProtocol {

    public init(literalCapacity: Int, interpolationCount: Int) {
      messageContent.reserveCapacity(literalCapacity + interpolationCount)
    }

    public mutating func appendLiteral(_ literal: StringLiteralType) {
      messageContent.components.append(.text(literal))
    }

    public mutating func appendInterpolation(_ breakpoint: Claude.Beta.CacheBreakpoint) {
      messageContent.components.append(.cacheBreakpoint(breakpoint))
    }

    /// The following methods mirror those defined on `DefaultStringInterpolation`
    public mutating func appendInterpolation<T>(_ value: T)
    where T: CustomStringConvertible, T: TextOutputStreamable {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation<T>(_ value: T) where T: TextOutputStreamable {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation<T>(_ value: T) where T: CustomStringConvertible {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation<T>(_ value: T) {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation(_ value: any Any.Type) {
      appendInterpolation(raw: value)
    }

    /// `raw:`-prefixed methods to override other interpolations.
    public mutating func appendInterpolation<T>(raw value: T)
    where T: CustomStringConvertible, T: TextOutputStreamable {
      messageContent.components.append(.text("\(value)"))
    }
    public mutating func appendInterpolation<T>(raw value: T) where T: TextOutputStreamable {
      messageContent.components.append(.text("\(value)"))
    }
    public mutating func appendInterpolation<T>(raw value: T) where T: CustomStringConvertible {
      messageContent.components.append(.text("\(value)"))
    }
    public mutating func appendInterpolation<T>(raw value: T) {
      messageContent.components.append(.text("\(value)"))
    }
    public mutating func appendInterpolation(raw value: any Any.Type) {
      messageContent.components.append(.text("\(value)"))
    }

    fileprivate var messageContent = MessageContent()

  }

}

// MARK: - Result Builder

extension Claude.ExpressibleByMessageContent {

  public init(@Claude.MessageContentBuilder<Self> _ builder: () throws -> Self) rethrows {
    self = try builder()
  }

}

extension Claude {

  @resultBuilder
  public struct MessageContentBuilder<Result: ExpressibleByMessageContent> {

    public static func buildExpression(_ component: Component) -> Component {
      component
    }

    public static func buildExpression(_ expression: Claude.Beta.CacheBreakpoint) -> Component {
      Component(messageContent: MessageContent([.cacheBreakpoint(expression)]))
    }

    public static func buildBlock(_ components: Component...) -> Component {
      Component(messageContent: components.map(\.messageContent).joined())
    }

    public static func buildFinalResult(_ component: Component) -> Result {
      Result(messageContent: component.messageContent)
    }

    public struct Component {

      init(messageContent: MessageContent) {
        self.messageContent = messageContent
      }

      fileprivate let messageContent: MessageContent

    }

  }

}

// MARK: - Supports Images In Messsage Content

extension Claude {

  public protocol SupportsImagesInMessageContent: ExpressibleByMessageContent {

  }

}

extension Claude.SupportsImagesInMessageContent {

  #if canImport(UIKit)
    public init(
      _ image: UIImage
    ) {
      self.init(Claude.PlatformImage(image))
    }
  #endif

  #if canImport(AppKit)
    public init(
      _ image: NSImage
    ) {
      self.init(Claude.PlatformImage(image))
    }
  #endif

  public init(
    _ image: Claude.Image
  ) {
    self.init(
      messageContent: MessageContent(
        [.image(image)]
      )
    )
  }

}

extension Claude.SupportsImagesInMessageContent where Self: Claude.MessageContentRepresentable {

  #if canImport(UIKit)
    public mutating func append(
      _ image: UIImage
    ) {
      append(Claude.PlatformImage(image))
    }
  #endif

  #if canImport(AppKit)
    public mutating func append(
      _ image: NSImage
    ) {
      append(Claude.PlatformImage(image))
    }
  #endif

  public mutating func append(
    _ image: Claude.Image
  ) {
    messageContent.append(
      contentsOf: MessageContent(
        [.image(image)]
      )
    )
  }

}

extension Claude.MessageContentStringInterpolation
where Component: Claude.SupportsImagesInMessageContent {

  #if canImport(UIKit)
    public mutating func appendInterpolation(
      _ image: UIImage,
      cacheBreakpoint: Claude.Beta.CacheBreakpoint? = nil
    ) {
      messageContent.components.append(.image(image))
      if let cacheBreakpoint {
        messageContent.components.append(.cacheBreakpoint(cacheBreakpoint))
      }
    }
  #endif

  #if canImport(AppKit)
    public mutating func appendInterpolation(
      _ image: NSImage,
      cacheBreakpoint: Claude.Beta.CacheBreakpoint? = nil
    ) {
      messageContent.components.append(.image(image))
      if let cacheBreakpoint {
        messageContent.components.append(.cacheBreakpoint(cacheBreakpoint))
      }
    }
  #endif

  public mutating func appendInterpolation(
    _ image: Claude.Image,
    cacheBreakpoint: Claude.Beta.CacheBreakpoint? = nil
  ) {
    messageContent.components.append(.image(image))
    if let cacheBreakpoint {
      messageContent.components.append(.cacheBreakpoint(cacheBreakpoint))
    }
  }

}

extension Claude.MessageContentBuilder where Result: Claude.SupportsImagesInMessageContent {

  #if canImport(UIKit)
    public static func buildExpression(
      _ image: UIImage
    ) -> Component {
      Component(
        messageContent: Claude.MessageContent(
          [
            .image(image)
          ]
        )
      )
    }
  #endif

  #if canImport(AppKit)
    public static func buildExpression(
      _ image: NSImage
    ) -> Component {
      Component(
        messageContent: Claude.MessageContent(
          [
            .image(image)
          ]
        )
      )
    }
  #endif

  public static func buildExpression(
    _ image: Claude.Image
  ) -> Component {
    Component(
      messageContent: Claude.MessageContent(
        [
          .image(image)
        ]
      )
    )
  }

}
