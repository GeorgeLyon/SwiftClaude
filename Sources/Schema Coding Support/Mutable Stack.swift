private import BasicContainers

public struct MutableStack: ~Copyable {

  public struct Reference<Value: ~Copyable> {
    fileprivate let stackID: MutableStack.ID

    fileprivate struct Container: ~Copyable {

      /// This is primarily used for sanity checking
      let type: any (~Copyable).Type = Value.self

      var value: Value

    }

    /// The raw pointer to the data managed by this reference
    /// This is used to perform the initialization of the value, since the memory isn't initially bound to `Container.self`
    fileprivate var rawPointer: UnsafeMutableRawPointer {
      previousEndPointer
        .alignedUp(for: Container.self)
    }

    /// The pointer to the data managed by this reference
    fileprivate var pointer: UnsafeMutablePointer<Container> {
      rawPointer
        .assumingMemoryBound(to: Container.self)
    }

    /// The pointer to the byte after the data managed by this reference
    fileprivate var endPointer: UnsafeMutableRawPointer {
      UnsafeMutableRawPointer(pointer)
        .advanced(by: MemoryLayout<Container>.size)
    }

    /// The pointer to the end of the data managed by the previous reference in the stack
    fileprivate let previousEndPointer: UnsafeMutableRawPointer
  }

  public mutating func push<Value: ~Copyable>(_ value: consuming Value) -> Reference<Value> {
    guard case .active = state else {
      fatalError()
    }
    guard let index = blocks.indices.last else {
      return pushToEmptyBlock(value)
    }
    if blocks[index].canPush(Value.self) {
      return blocks[index].push(stackID: id, value: value)
    } else {
      return pushToEmptyBlock(value)
    }
  }

  private mutating func pushToEmptyBlock<Value: ~Copyable>(
    _ value: consuming Value
  ) -> Reference<Value> {
    let index = emptyBlocks.indices.first { index in
      emptyBlocks[index].canPush(Value.self)
    }
    var block: Block
    if let index {
      block = emptyBlocks.remove(at: index)
    } else {
      /// Create a new block
      block = Block(
        byteCount: max(4096, MemoryLayout<Reference<Value>.Container>.size),
        alignment: MemoryLayout<Reference<Value>.Container>.alignment
      )
    }

    let reference = block.push(stackID: id, value: value)
    blocks.append(block)
    return reference
  }

  public mutating func pop<Value: ~Copyable>(_ reference: Reference<Value>) -> Value {
    state = .popping
    let index: Int
    let lastIndex: Int = blocks.indices.last!
    if blocks[lastIndex].cursor == blocks[lastIndex].buffer.baseAddress {
      /// Pop the last block
      emptyBlocks.append(blocks.removeLast())
      index = blocks.indices.last!
    } else {
      index = lastIndex
    }

    /// Validate the reference
    /// This validation is subtly different than the validation we do in `withValue`
    guard reference.stackID == id else {
      /// This reference is no longer valid
      fatalError()
    }
    guard reference.endPointer == blocks[index].cursor else {
      /// References must be popped in order
      fatalError()
    }
    let container = reference.pointer.move()
    guard container.type == Value.self else {
      fatalError()
    }

    blocks[index].cursor = reference.previousEndPointer

    return container.value
  }

  public func withValue<Value, T>(
    for reference: Reference<Value>,
    operation: (inout Value) throws -> T
  ) rethrows -> T {
    validate(reference)
    return try operation(&reference.pointer.pointee.value)
  }

  public func withValue<Value, T>(
    for reference: Reference<Value>,
    operation: (inout Value) async throws -> T
  ) async rethrows -> T {
    validate(reference)
    return try await operation(&reference.pointer.pointee.value)
  }

  private func validate<Value>(_ reference: Reference<Value>) {
    guard case .active = state else {
      fatalError()
    }
    guard reference.stackID == id else {
      /// This reference is no longer valid
      fatalError()
    }
    guard reference.pointer.pointee.type == Value.self else {
      /// Sanity check failed
      fatalError()
    }
  }

  fileprivate typealias ID = UniqueID<Self>
  private let id = ID()

  private enum State {
    case active
    case popping
  }
  private var state: State = .active

  private struct Block: ~Copyable {

    fileprivate func canPush<Value: ~Copyable>(_ type: Value.Type) -> Bool {
      let candidate = Reference<Value>(
        stackID: .invalid,
        previousEndPointer: cursor
      )
      return validCursorRange.contains(candidate.endPointer)
    }

    fileprivate mutating func push<Value: ~Copyable>(
      stackID: ID,
      value: consuming Value
    ) -> Reference<Value> {
      let reference = Reference<Value>(
        stackID: stackID,
        previousEndPointer: cursor
      )
      let pointer = reference.rawPointer
        .bindMemory(to: Reference<Value>.Container.self, capacity: 1)
      pointer.initialize(to: .init(value: value))
      cursor = reference.endPointer
      return reference
    }

    fileprivate init(
      byteCount: Int,
      alignment: Int
    ) {
      buffer = .allocate(byteCount: byteCount, alignment: alignment)
      cursor = buffer.baseAddress!
    }

    fileprivate let buffer: UnsafeMutableRawBufferPointer
    fileprivate var cursor: UnsafeMutableRawPointer {
      didSet {
        guard validCursorRange.contains(cursor) else {
          fatalError()
        }
      }
    }
    deinit {
      guard cursor == buffer.baseAddress else {
        /// We can only deallocate empty blocks
        fatalError()
      }
      buffer.deallocate()
    }

    private var validCursorRange: ClosedRange<UnsafeMutableRawPointer> {
      buffer.baseAddress!...buffer.baseAddress!.advanced(by: buffer.count)
    }
  }
  private var blocks = UniqueArray<Block>()

  private var emptyBlocks: UniqueArray<Block>

}

extension MutableStack.ID {

  /// An ID that will never be valid in any stack
  fileprivate static let invalid = Self()

}
