struct MutableStack: ~Copyable, @unchecked Sendable {
  typealias ID = UniqueID<MutableStack>

  struct Reference<T: Sendable>: Sendable {
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
    let reference = Reference<T>(
      stackID: id,
      previousElementEndOffset: lastElementEndOffset
    )
    buffer.baseAddress!
      .bindMemory(to: T.self, capacity: 1)
      .initialize(to: value)
    lastElementEndOffset = reference.endOffset
    return reference
  }

  mutating func pop<T>(_ reference: Reference<T>) {
    guard reference.stackID == id else {
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

  subscript<T>(reference: Reference<T>) -> T {
    get { withPointer(to: reference) { $0.pointee } }
    set { withPointer(to: reference) { $0.pointee = newValue } }
  }

  private func withPointer<T, U>(
    to reference: Reference<T>,
    _ body: (UnsafeMutablePointer<T>) throws -> U
  ) rethrows -> U {
    guard reference.stackID == id else {
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

  init() {
    buffer = .allocate(byteCount: 4096, alignment: 64)
  }

  deinit {
    guard lastElementEndOffset == 0 else {
      /// Not all elements were popped
      fatalError()
    }
    buffer.deallocate()
  }

  private let id = ID()
  private let buffer: UnsafeMutableRawBufferPointer
  private var lastElementEndOffset: Int = 0
}
