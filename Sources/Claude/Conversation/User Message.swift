public import Observation


extension Claude {
  
  @Observable
  public final class ConversationUserMessage<Image>: Identifiable {
    
    public init() {
      contentBlocks = []
    }
    
    public enum ContentBlock {
      case text(String)
      case image(Image)
    }
    public var contentBlocks: [ContentBlock]
    
  }
  
}
