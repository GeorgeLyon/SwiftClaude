private import BasicContainers

// MARK: - Arena

public struct Arena: ~Copyable {

  public init() {
    self.init(emptyBlocks: .init(), emptyBitwiseCopyableBlocks: .init())
  }
  private init(
    emptyBlocks: consuming UniqueArray<Block>,
    emptyBitwiseCopyableBlocks: consuming UniqueArray<BitwiseCopyableBlock>
  ) {
    self.emptyBlocks = emptyBlocks
    self.emptyBitwiseCopyableBlocks = emptyBitwiseCopyableBlocks
  }

  public mutating func reset() {
    var emptyBlocks = self.emptyBlocks
    while var block = blocks.popLast() {
      block.reset()
      emptyBlocks.append(block)
    }

    var emptyBitwiseCopyableBlocks = self.emptyBitwiseCopyableBlocks
    while var block = bitwiseCopyableBlocks.popLast() {
      block.reset()
      emptyBitwiseCopyableBlocks.append(block)
    }

    self = Arena(
      emptyBlocks: emptyBlocks,
      emptyBitwiseCopyableBlocks: emptyBitwiseCopyableBlocks
    )

  }

  fileprivate typealias ID = UniqueID<Arena>

  private let id = ID()

  private var blocks: UniqueArray<Block> = .init()
  private var emptyBlocks: UniqueArray<Block>

  private var bitwiseCopyableBlocks: UniqueArray<BitwiseCopyableBlock> = .init()
  private var emptyBitwiseCopyableBlocks: UniqueArray<BitwiseCopyableBlock>

}

// MARK: - Reference

extension Arena {

  public subscript<Value>(reference: Reference<Value>) -> Value {
    get { withValue(for: reference) { $0 } }
    set { withValue(for: reference) { $0 = newValue } }
  }

  public func withValue<Value: ~Copyable, T, Failure>(
    for reference: Reference<Value>,
    _ operation: (inout Value) throws(Failure) -> T
  ) throws(Failure) -> T {
    guard reference.arenaID == id else {
      fatalError()
    }
    return try operation(&reference.pointer.pointee)
  }

  public struct Reference<Value: ~Copyable> {
    fileprivate let arenaID: Arena.ID
    fileprivate let pointer: UnsafeMutablePointer<Value>
  }

}

// MARK: - Data Requiring Deinitialization

extension Arena {

  public mutating func allocate<Value>(_ value: Value) -> Reference<Value> {
    if let index = blocks.indices.last,
      blocks[index].canAllocate(Value.self)
    {
      return blocks[index].allocate(value, arenaID: id)
    } else {
      /// Push this value to an empty block
      let index = emptyBlocks
        .indices
        .reversed()
        .first { index in
          emptyBlocks[index].canAllocate(Value.self)
        }
      var block: Block
      if let index {
        block = emptyBlocks.remove(at: index)
      } else {
        /// Create a new block
        block = Block(
          minimumByteCount: 4096,
          minimumAlignment: MemoryLayout<Int>.alignment,
          nextValue: Value.self
        )
      }

      let reference = block.allocate(value, arenaID: id)
      blocks.append(block)
      return reference
    }
  }

  private struct Block: ~Copyable {

    public func canAllocate<Value: ~Copyable>(
      _ value: Value.Type
    ) -> Bool {
      buffer.validCursorRange.contains(
        buffer.cursor
          .alignedUp(for: Value.self)
          .advanced(by: MemoryLayout<Value>.size)
          .alignedUp(for: ValueMetadata.self)
          .advanced(by: MemoryLayout<ValueMetadata>.size)
      )
    }

    public mutating func allocate<Value: ~Copyable>(
      _ value: consuming Value,
      arenaID: Arena.ID
    ) -> Reference<Value> {
      guard canAllocate(Value.self) else {
        fatalError()
      }
      let valuePointer =
        buffer.cursor
        .alignedUp(for: Value.self)
        .bindMemory(to: Value.self, capacity: 1)
      valuePointer.initialize(to: value)
      let metadataPointer =
        UnsafeMutableRawPointer(valuePointer)
        .advanced(by: MemoryLayout<Value>.size)
        .alignedUp(for: ValueMetadata.self)
        .bindMemory(to: ValueMetadata.self, capacity: 1)
      metadataPointer.initialize(to: ValueMetadata(type: Value.self))
      buffer.cursor = UnsafeMutableRawPointer(valuePointer)
        .advanced(by: MemoryLayout<ValueMetadata>.size)
      return Reference(arenaID: arenaID, pointer: valuePointer)
    }

    /// This must only be called when resetting an `Arena` ensuring the old `Arena.ID` is no longer availble to allow access to data in this block.
    public mutating func reset() {
      deinitializeContents()
      buffer.cursor = buffer.storage.baseAddress!
    }

    init<Value>(
      minimumByteCount: Int,
      minimumAlignment: Int,
      nextValue: Value.Type
    ) {
      buffer = .init(
        byteCount: max(
          minimumByteCount,
          MemoryLayout<Value>.stride(to: ValueMetadata.self) + MemoryLayout<ValueMetadata>.size,
        ),
        alignment: max(
          minimumAlignment,
          MemoryLayout<Value>.alignment,
          MemoryLayout<ValueMetadata>.alignment,
        )
      )
    }
    deinit {
      /// This should only happen when an `Arena` is deinitialized, which means that no other `Arena` should exist with an ID that would allow references to access data in this block.
      deinitializeContents()
    }

    /// All references to data in this block have been invalidated when this is called.
    ///
    /// This deinitializes the contents in LIFO order, similar to how exiting a scope works.
    private func deinitializeContents() {
      var deallocationCursor = buffer.cursor
      func pop<Value>(_ value: Value) {
        deallocationCursor =
          deallocationCursor
          /// We assume advancing by a negative size and aligning down is the reverse operation of aligning up and advancing by size.
          .advanced(by: -MemoryLayout<Value>.size)
          .alignedDown(for: Value.self)
          .assumingMemoryBound(to: Value.self)
          .deinitialize(count: 1)
          .advanced(by: MemoryLayout<Value>.size)
      }
      while deallocationCursor > buffer.storage.baseAddress! {
        /// The cursor should always be pointing to the end of a metadata segment.
        /// First, we rewind it to point to the start of the metadata segment.
        deallocationCursor =
          deallocationCursor
          .advanced(by: -MemoryLayout<ValueMetadata>.size)
        /// Then, we get the type from the metadata
        let type =
          deallocationCursor
          .assumingMemoryBound(to: ValueMetadata.self)
          .pointee.type
        /// Finally, we pop a value of that type
        pop(type)
      }
      guard deallocationCursor == buffer.storage.baseAddress! else {
        fatalError()
      }
    }

    /// `Block` stores each value followed by an aligned `ValueMetadata`.
    /// The cursor always points to either the end of `ValueMetadata` or to the start of the buffer.
    private var buffer: CursedBuffer

    private struct ValueMetadata {
      let type: any (~Copyable).Type
    }

  }

}

// MARK: - Bitwise Copyable Data

extension Arena {

  public mutating func allocate<Value: BitwiseCopyable>(_ value: Value) -> Reference<Value> {
    if let index = bitwiseCopyableBlocks.indices.last,
      bitwiseCopyableBlocks[index].canAllocate(Value.self)
    {
      return bitwiseCopyableBlocks[index].allocate(value, arenaID: id)
    } else {
      /// Push this value to an empty block
      let index = emptyBitwiseCopyableBlocks
        .indices
        .reversed()
        .first { index in
          emptyBitwiseCopyableBlocks[index].canAllocate(Value.self)
        }
      var block: BitwiseCopyableBlock
      if let index {
        block = emptyBitwiseCopyableBlocks.remove(at: index)
      } else {
        /// Create a new block
        block = BitwiseCopyableBlock(
          minimumByteCount: 4096,
          minimumAlignment: MemoryLayout<Int>.alignment,
          nextValue: Value.self
        )
      }

      let reference = block.allocate(value, arenaID: id)
      bitwiseCopyableBlocks.append(block)
      return reference
    }
  }

  private struct BitwiseCopyableBlock: ~Copyable {

    public func canAllocate<Value: BitwiseCopyable>(
      _ value: Value.Type
    ) -> Bool {
      buffer.validCursorRange.contains(
        buffer.cursor
          .alignedUp(for: Value.self)
          .advanced(by: MemoryLayout<Value>.size)
      )
    }

    public mutating func allocate<Value: BitwiseCopyable>(
      _ value: consuming Value,
      arenaID: Arena.ID
    ) -> Reference<Value> {
      let pointer = buffer.cursor
        .alignedUp(for: Value.self)
        .bindMemory(to: Value.self, capacity: 1)
      pointer.initialize(to: value)
      buffer.cursor = UnsafeMutableRawPointer(pointer)
        .advanced(by: MemoryLayout<Value>.size)
      return Reference(arenaID: arenaID, pointer: pointer)
    }

    /// This must only be called when resetting an `Arena` ensuring the old `Arena.ID` is no longer availble to allow access to data in this block.
    public mutating func reset() {
      buffer.cursor = buffer.storage.baseAddress!
    }

    init<Value>(
      minimumByteCount: Int,
      minimumAlignment: Int,
      nextValue: Value.Type
    ) {
      buffer = .init(
        byteCount: max(minimumByteCount, MemoryLayout<Value>.size),
        alignment: max(minimumAlignment, MemoryLayout<Value>.alignment)
      )
    }
    deinit {
      /// This should only happen when an `Arena` is deinitialized, which means that no other `Arena` should exist with an ID that would allow references to access data in this block.
      buffer.storage.deallocate()
    }

    private var buffer: CursedBuffer

  }

}

// MARK: - Support

extension Arena {

  private struct CursedBuffer: ~Copyable {

    fileprivate init(
      byteCount: Int,
      alignment: Int
    ) {
      storage = .allocate(byteCount: byteCount, alignment: alignment)
      cursor = storage.baseAddress!
    }
    deinit {
      storage.deallocate()
    }
    fileprivate let storage: UnsafeMutableRawBufferPointer

    fileprivate var cursor: UnsafeMutableRawPointer {
      didSet {
        guard oldValue < cursor else {
          fatalError()
        }
        guard validCursorRange.contains(cursor) else {
          fatalError()
        }
      }
    }

    fileprivate var validCursorRange: ClosedRange<UnsafeMutableRawPointer> {
      let baseAddress = storage.baseAddress!
      return baseAddress...baseAddress.advanced(by: storage.count)
    }

  }

}

extension MemoryLayout {

  /// - Returns:
  ///     The stride from a value of T to an aligned value of U.
  ///     T must be aligned to the greater of the alignment of T and U.
  fileprivate static func stride<U>(to type: U.Type) -> Int {
    let alignment = MemoryLayout<U>.alignment
    return (size + alignment - 1) & (alignment - 1)
  }

}
