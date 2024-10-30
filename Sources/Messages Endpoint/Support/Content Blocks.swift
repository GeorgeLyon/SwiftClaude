public import ClaudeClient

extension ClaudeClient.MessagesEndpoint {

  /// Helper type for managing the state of content blocks
  public struct ContentBlocks<ContentBlock> {

    public init() {
      elements = []
    }

    public mutating func start(
      _ block: ContentBlock,
      at index: Int
    ) throws {
      /// The only valid insertion point is at the end
      guard index == elements.count else {
        throw ContentBlocksError.InvalidInsertion(index: index)
      }
      elements.append(.started(block))
    }

    public mutating func withContentBlock(
      at index: Int,
      _ body: (inout ContentBlock) throws -> Void
    ) throws {
      try withElement(at: index) { element in
        switch element {
        case .started(var block):
          element = .mutating
          defer { element = .started(block) }
          try body(&block)
        case .stopped:
          throw ContentBlocksError.UseAfterStop(index: index)
        case .mutating:
          assertionFailure()
          throw ContentBlocksError.ConcurrentMutation(index: index)
        }
      }
    }

    public mutating func stop(at index: Int) throws -> ContentBlock {
      try withElement(at: index) { element in
        switch element {
        case .started(let block):
          element = .stopped
          return block
        case .stopped:
          throw ContentBlocksError.UseAfterStop(index: index)
        case .mutating:
          assertionFailure()
          throw ContentBlocksError.ConcurrentMutation(index: index)
        }
      }
    }

    public var allStopped: Bool {
      get throws {
        try elements.enumerated().allSatisfy { offset, element in
          switch element {
          case .started:
            return false
          case .mutating:
            assertionFailure()
            throw ContentBlocksError.ConcurrentMutation(index: offset)
          case .stopped:
            return true
          }
        }
      }
    }

    public mutating func stopRemaining() -> [ContentBlock] {
      var stoppedBlocks: [ContentBlock] = []
      for index in elements.indices {
        switch elements[index] {
        case .started(let block):
          elements[index] = .stopped
          stoppedBlocks.append(block)
        case .stopped:
          break
        case .mutating:
          /// `stopRemaining` is called in response to an error, so we don't have an opportunity to throw another error
          assertionFailure()
          break
        }
      }
      return stoppedBlocks
    }

    private mutating func withElement<T>(
      at index: Int,
      _ body: (inout Element) throws -> T
    ) throws -> T {
      guard (0..<elements.count).contains(index) else {
        throw ContentBlocksError.InvalidIndex(index: index)
      }
      return try body(&elements[index])
    }

    private enum Element {
      case started(ContentBlock)

      /// When a content block is stopped we relinquish our reference to it
      /// If the block was previously in a `failed` state, the error will be persisted
      case stopped

      /// A special state for while we are mutating a block
      /// This allows things like arrays in the block to be `isKnownUniquelyReferenced`
      /// For more details, see:
      /// https://forums.swift.org/t/in-place-mutation-of-an-enum-associated-value/11747
      case mutating
    }
    private var elements: [Element]
  }

  private enum ContentBlocksError {
    struct InvalidInsertion: Error {
      let index: Int
    }
    struct InvalidIndex: Error {
      let index: Int
    }
    struct UseAfterStop: Error {
      let index: Int
    }
    struct ConcurrentMutation: Error {
      let index: Int
    }
  }
}
