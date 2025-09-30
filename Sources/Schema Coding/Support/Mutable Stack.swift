struct MutableStack: ~Copyable {

  struct Reference<T> {
    fileprivate var startOffset: Int {
      let alignment = MemoryLayout<T>.alignment
      return (previousElementEndOffset + alignment - 1) & ~(alignment - 1)
    }
    fileprivate var endOffset: Int {
      startOffset + MemoryLayout<T>.size
    }
    fileprivate init(
      stackID: MutableStack.ID,
      previousElementEndOffset: Int
    ) {
      self.stackID = stackID
      self.previousElementEndOffset = previousElementEndOffset
    }
    fileprivate let stackID: MutableStack.ID
    fileprivate let previousElementEndOffset: Int
  }

  mutating func push<T>(_ value: T) -> Reference<T> {
    if let reference = blocks.last?.push(value, stackID: id) {
      return reference
    } else {
      let (reference, block) = pushToEmptyBlock(value)
      blocks.append(block)
      return reference
    }
  }

  mutating func pop<T>(_ reference: Reference<T>) {
    guard let block = blocks.last else {
      /// Popping past end
      fatalError()
    }
    block.pop(reference, stackID: id)
    if block.isEmpty {
      blocks.removeLast()
      emptyBlocks.append(block)
    }
  }

  init(blockSize: Int = 4096) {
    self.blockSize = blockSize
  }

  deinit {
    guard blocks.isEmpty else {
      /// Not all elements were popped
      fatalError()
    }
  }

  private mutating func pushToEmptyBlock<T>(_ value: T) -> (Reference<T>, MutableStackBlock) {
    for blockIndex in emptyBlocks.indices.reversed() {
      if let reference = blocks[blockIndex].push(value, stackID: id) {
        emptyBlocks.remove(at: blockIndex)
        return (reference, blocks[blockIndex])
      }
    }
    /// No suitable block found
    let block = MutableStackBlock(
      byteCount: max(MemoryLayout<T>.size, 4096),
      alignment: max(MemoryLayout<T>.alignment, MemoryLayout<Int64>.alignment)
    )
    guard let reference = block.push(value, stackID: id) else {
      /// This should never fail because we reserved enough space above
      fatalError()
    }
    return (reference, block)
  }

  fileprivate typealias ID = UniqueID<MutableStack>

  private let blockSize: Int
  private var blocks: [MutableStackBlock] = []
  private var emptyBlocks: [MutableStackBlock] = []
  private let id = ID()

}

private final class MutableStackBlock {

  typealias Reference = MutableStack.Reference

  func push<T>(_ value: T, stackID: MutableStack.ID) -> Reference<T>? {
    let reference = Reference<T>(
      stackID: stackID,
      previousElementEndOffset: lastElementEndOffset
    )
    guard reference.endOffset <= buffer.count else {
      /// There is insufficient space for this value
      return nil
    }
    buffer.baseAddress!
      .advanced(by: reference.startOffset)
      .bindMemory(to: T.self, capacity: 1)
      .initialize(to: value)
    lastElementEndOffset = reference.endOffset
    return reference
  }

  func pop<T>(_ reference: Reference<T>, stackID: MutableStack.ID) {
    guard reference.stackID == stackID else {
      fatalError()
    }
    guard lastElementEndOffset == reference.endOffset else {
      /// Elements must be popped in order
      fatalError()
    }
    buffer.baseAddress!
      .advanced(by: reference.startOffset)
      .assumingMemoryBound(to: T.self)
      .deinitialize(count: 1)
    lastElementEndOffset = reference.previousElementEndOffset
  }

  func withPointer<T, U>(
    to reference: Reference<T>,
    stackID: MutableStack.ID,
    _ body: (UnsafeMutablePointer<T>) throws -> U
  ) rethrows -> U {
    guard reference.stackID == stackID else {
      fatalError()
    }
    guard lastElementEndOffset >= reference.endOffset else {
      /// Element must be valid
      fatalError()
    }
    let pointer = buffer.baseAddress!
      .advanced(by: reference.startOffset)
      .assumingMemoryBound(to: T.self)
    return try body(pointer)
  }

  init(byteCount: Int = 4096, alignment: Int = 64) {
    buffer = .allocate(byteCount: byteCount, alignment: alignment)
  }

  deinit {
    guard isEmpty else {
      fatalError()
    }
    buffer.deallocate()
  }

  var isEmpty: Bool {
    lastElementEndOffset == 0
  }

  private let buffer: UnsafeMutableRawBufferPointer
  private var lastElementEndOffset: Int = 0

}
