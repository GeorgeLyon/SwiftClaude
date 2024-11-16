public import Observation

extension Claude {
  
  @Observable
  public final class ConversationUserMessage<Conversation: Claude.Conversation>: Identifiable {
    
    public init() {
      contentBlocks = []
    }
    
    public init(contentBlocks: [ContentBlock]) {
      self.contentBlocks = contentBlocks
    }
    
    public enum ContentBlock {
      case text(String)
      case image(Conversation.UserMessageImage)
    }
    public var contentBlocks: [ContentBlock]
    
  }
  
}

// MARK: - Text-only Messages

extension Claude.ConversationUserMessage where Conversation.UserMessageImage == Never {
  
  public var text: String {
    contentBlocks
      .map { contentBlock in
        switch contentBlock {
        case .text(let text):
          return text
        }
      }
      .joined()
  }
  
}

// MARK: - Expressible By Array Literal

extension Claude.ConversationUserMessage: ExpressibleByArrayLiteral {
  
  public convenience init(arrayLiteral elements: ContentBlock...) {
    self.init(contentBlocks: elements)
  }
  
}

// MARK: - Expressible By String Interpolation

/// We can't rely on `MessageContentRepresentable` here because `ContentBlock` is an `enum` meant for public consumption.
extension Claude.ConversationUserMessage: ExpressibleByStringInterpolation {
  public convenience init(stringLiteral value: StringLiteralType) {
    self.init(contentBlocks: [.text(value)])
  }
  
  public convenience init(stringInterpolation: StringInterpolation) {
    self.init(contentBlocks: stringInterpolation.contentBlocks)
  }
  
  public struct StringInterpolation: StringInterpolationProtocol {
    
    public init(literalCapacity: Int, interpolationCount: Int) {
      contentBlocks.reserveCapacity(literalCapacity + interpolationCount)
    }
    
    public mutating func appendLiteral(_ literal: String) {
      contentBlocks.append(.text(literal))
    }
    
    /// `raw:`-prefixed methods to override other interpolations.
    public mutating func appendInterpolation<T>(raw value: T)
    where T: CustomStringConvertible, T: TextOutputStreamable {
      contentBlocks.append(.text("\(value)"))
    }
    public mutating func appendInterpolation<T>(raw value: T) where T: TextOutputStreamable {
      contentBlocks.append(.text("\(value)"))
    }
    public mutating func appendInterpolation<T>(raw value: T) where T: CustomStringConvertible {
      contentBlocks.append(.text("\(value)"))
    }
    public mutating func appendInterpolation<T>(raw value: T) {
      contentBlocks.append(.text("\(value)"))
    }
    public mutating func appendInterpolation(raw value: any Any.Type) {
      contentBlocks.append(.text("\(value)"))
    }

    fileprivate private(set) var contentBlocks: [Claude.ConversationUserMessage<Conversation>.ContentBlock] = []
  }
}

// MARK: - Message Content

extension Claude {

  public struct UserMessageContent: MessageContentRepresentable, SupportsImagesInMessageContent {

    public init() {
      self.messageContent = .init()
    }
    
    public init(messageContent: MessageContent) {
      self.messageContent = messageContent
    }

    public var messageContent: MessageContent

  }

}
