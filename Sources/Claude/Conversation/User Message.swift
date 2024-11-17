public import Observation

#if canImport(UIKit)
public import UIKit
#endif

#if canImport(AppKit)
public import AppKit
#endif

extension Claude {
  
  @Observable
  public final class ConversationUserMessage<Conversation: Claude.Conversation>: Identifiable {
    
    public init() {
      contentBlocks = []
    }
    
    public init(contentBlocks: [ContentBlock]) {
      self.contentBlocks = contentBlocks
    }
    
    public enum ContentBlock: Identifiable {
      case textBlock(TextBlock)
      case imageBlock(ImageBlock)
      
      public static func text(_ text: String) -> Self {
        .textBlock(.init(text: text))
      }
      public static func image(_ image: Image) -> Self {
        .imageBlock(.init(image: image))
      }
      
      public struct ID: Hashable {
        fileprivate enum Kind: Hashable {
          case textBlock(TextBlock.ID)
          case imageBlock(ImageBlock.ID)
        }
        fileprivate init(kind: Kind) {
          self.kind = kind
        }
        private let kind: Kind
      }
      public var id: ID {
        switch self {
        case .textBlock(let textBlock):
          ID(kind: .textBlock(textBlock.id))
        case .imageBlock(let imageBlock):
          ID(kind: .imageBlock(imageBlock.id))
        }
      }
    }
    public var contentBlocks: [ContentBlock]
    
    public typealias TextBlock = ConversationUserMessageTextBlock
    
    public typealias Image = Conversation.UserMessageImage
    
    public final class ImageBlock: Identifiable {
      public init(image: Image) {
        self.image = image
      }
      public let image: Image
    }
    
  }
  
  public final class ConversationUserMessageTextBlock: Identifiable {
    public init(text: String) {
      self.text = text
    }
    public let text: String
  }
  
}

// MARK: - Text-only Messages

extension Claude.ConversationUserMessage where Conversation.UserMessageImage == Never {
  
  public var text: String {
    contentBlocks
      .map { contentBlock in
        switch contentBlock {
        case .textBlock(let textBlock):
          return textBlock.text
        case .imageBlock(let imageBlock):
          switch imageBlock.image {
            
          }
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

#if canImport(UIKit)

extension Claude.ConversationUserMessage.StringInterpolation where Conversation.UserMessageImage == UIImage {
  
  public mutating func appendInterpolation(_ value: UIImage) {
    contentBlocks.append(.image(value))
  }
  
}

#endif

#if canImport(AppKit)

extension Claude.ConversationUserMessage.StringInterpolation where Conversation.UserMessageImage == NSImage {
  
  public mutating func appendInterpolation(_ value: NSImage) {
    contentBlocks.append(.image(value))
  }
  
}

#endif

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
