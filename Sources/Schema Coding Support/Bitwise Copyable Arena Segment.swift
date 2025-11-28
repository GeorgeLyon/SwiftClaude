private import BasicContainers

struct BitwiseCopyableArenaSegment: ~Copyable {

  mutating func push<Value: BitwiseCopyable>(_ value: Value) -> UnsafeMutablePointer<Value> {
    guard let index = slabs.indices.last else {
      return pushToEmptySlab(value)
    }
    if let pointer = slabs[index].push(value) {
      return pointer
    } else {
      return pushToEmptySlab(value)
    }
  }

  mutating func reset() {
    while !slabs.isEmpty {
      var slab = slabs.removeLast()
      slab.reset()
      emptySlabs.append(slab)
    }
  }

  private mutating func pushToEmptySlab<Value: BitwiseCopyable>(
    _ value: Value
  ) -> UnsafeMutablePointer<Value> {
    for index in emptySlabs.indices.reversed() {
      if let pointer = emptySlabs[index].push(value) {
        let slab = emptySlabs.remove(at: index)
        slabs.append(slab)
        return pointer
      }
    }
    /// We don't have an empty slab that can hold this value, so we create a new one
    var slab = BitwiseCopyableSlab(
      byteCount: max(MemoryLayout<Value>.size, 4096),
      alignment: max(MemoryLayout<Value>.alignment, MemoryLayout<Int>.alignment)
    )
    let pointer = slab.push(value)!
    slabs.append(slab)
    return pointer
  }

  private var slabs: UniqueArray<BitwiseCopyableSlab> = .init()
  private var emptySlabs: UniqueArray<BitwiseCopyableSlab> = .init()

}

struct BitwiseCopyableSlab: ~Copyable {

  /// - Returns: `nil` if the value doesn't fit on this slab
  fileprivate mutating func push<Value: BitwiseCopyable>(_ value: Value) -> UnsafeMutablePointer<
    Value
  >? {
    let candidate = cursor.alignedUp(for: Value.self)
    let nextCursor = candidate + MemoryLayout<Value>.size
    guard nextCursor < (buffer.baseAddress! + buffer.count) else {
      return nil
    }
    let pointer =
      candidate
      .bindMemory(to: Value.self, capacity: 1)
    pointer.initialize(to: value)
    return pointer
  }

  fileprivate mutating func reset() {
    cursor = buffer.baseAddress!
  }

  fileprivate init(
    byteCount: Int,
    alignment: Int
  ) {
    buffer = .allocate(byteCount: byteCount, alignment: alignment)
    cursor = buffer.baseAddress!
  }

  private let buffer: UnsafeMutableRawBufferPointer
  private var cursor: UnsafeMutableRawPointer

  deinit {
    /// Because all of the types we added are `BitwiseCopyable` this is safe
    buffer.deallocate()
  }
}
