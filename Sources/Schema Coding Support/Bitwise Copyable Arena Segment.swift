private import BasicContainers

struct BitwiseCopyableArenaSegment: ~Copyable {

  mutating func push<Value: BitwiseCopyable>(_ value: Value) -> UnsafeMutablePointer<Value> {
    bitwiseCopyableElementCount += 1
    return unsafePush(value)
  }

  mutating func pushPOD<Value>(_ value: Value) -> UnsafeMutablePointer<Value> {
    assert(_isPOD(Value.self))
    podElementCount += 1
    return unsafePush(value)
  }

  private mutating func unsafePush<Value>(_ value: Value) -> UnsafeMutablePointer<Value> {
    assert(_isPOD(Value.self))
    guard let index = slabs.indices.last else {
      return unsafePushToEmptySlab(value)
    }
    if let pointer = slabs[index].unsafePush(value) {
      return pointer
    } else {
      return unsafePushToEmptySlab(value)
    }
  }

  private mutating func unsafePushToEmptySlab<Value>(
    _ value: Value
  ) -> UnsafeMutablePointer<Value> {
    for index in emptySlabs.indices.reversed() {
      if let pointer = emptySlabs[index].unsafePush(value) {
        let slab = emptySlabs.remove(at: index)
        slabs.append(slab)
        return pointer
      }
    }
    /// We don't have an empty slab that can hold this value, so we create a new one
    var slab = BitwiseCopyableSlab(
      byteCount: max(MemoryLayout<Value>.size, slabMinimumByteCount),
      alignment: max(MemoryLayout<Value>.alignment, slabMinimumAlignment)
    )
    let pointer = slab.unsafePush(value)!
    slabs.append(slab)
    return pointer
  }

  mutating func reset() {
    while !slabs.isEmpty {
      var slab = slabs.removeLast()
      slab.reset()
      emptySlabs.append(slab)
    }
    bitwiseCopyableElementCount = 0
    podElementCount = 0
  }

  init(
    slabMinimumByteCount: Int,
    slabMinimumAlignment: Int
  ) {
    self.slabMinimumByteCount = slabMinimumByteCount
    self.slabMinimumAlignment = slabMinimumAlignment
  }

  var stats: Arena.BitwiseCopyableSegmentStats {
    Arena.BitwiseCopyableSegmentStats(
      bitwiseCopyableElementCount: bitwiseCopyableElementCount,
      podElementCount: podElementCount,
      slabCount: slabs.count,
      emptySlabCount: emptySlabs.count
    )
  }

  private var bitwiseCopyableElementCount = 0
  private var podElementCount = 0
  private var slabs: UniqueArray<BitwiseCopyableSlab> = .init()
  private var emptySlabs: UniqueArray<BitwiseCopyableSlab> = .init()
  private let slabMinimumByteCount: Int
  private let slabMinimumAlignment: Int

}

struct BitwiseCopyableSlab: ~Copyable {

  /// - Returns: `nil` if the value doesn't fit on this slab
  fileprivate mutating func unsafePush<Value>(_ value: Value) -> UnsafeMutablePointer<Value>? {
    let candidate = cursor.alignedUp(for: Value.self)
    let nextCursor = candidate + MemoryLayout<Value>.size
    guard nextCursor <= (buffer.baseAddress! + buffer.count) else {
      return nil
    }
    cursor = nextCursor
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
