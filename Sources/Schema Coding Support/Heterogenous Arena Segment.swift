private import BasicContainers

struct HeterogenousArenaSegment: ~Copyable {

  mutating func push<Value: ~Copyable>(_ value: consuming Value) -> UnsafeMutablePointer<Value> {
    guard let index = slabs.indices.last else {
      return pushToEmptySlab(value)
    }
    switch slabs[index].push(value) {
    case .pointer(let pointer):
      return pointer
    case .value(let value):
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

  init(
    slabMinimumByteCount: Int,
    slabMinimumAlignment: Int
  ) {
    self.slabMinimumByteCount = slabMinimumByteCount
    self.slabMinimumAlignment = slabMinimumAlignment
  }

  private mutating func pushToEmptySlab<Value: ~Copyable>(
    _ value: consuming Value
  ) -> UnsafeMutablePointer<Value> {
    var value = value
    for index in emptySlabs.indices.reversed() {
      switch emptySlabs[index].push(value) {
      case .pointer(let pointer):
        let slab = emptySlabs.remove(at: index)
        slabs.append(slab)
        return pointer
      case .value(let v):
        value = v
      }
    }
    /// We don't have an empty slab that can hold this value, so we create a new one
    var slab = HeterogenousSlab(
      byteCount: max(MemoryLayout<Value>.size, slabMinimumByteCount),
      alignment: max(MemoryLayout<Value>.alignment, slabMinimumAlignment)
    )
    guard case .pointer(let pointer) = slab.push(value) else {
      fatalError()
    }
    slabs.append(slab)
    return pointer
  }

  private var slabs: UniqueArray<HeterogenousSlab> = .init()
  private var emptySlabs: UniqueArray<HeterogenousSlab> = .init()
  private let slabMinimumByteCount: Int
  private let slabMinimumAlignment: Int

}

struct HeterogenousSlab: ~Copyable {

  fileprivate enum PushResult<Value: ~Copyable>: ~Copyable {
    case pointer(UnsafeMutablePointer<Value>)
    case value(Value)
  }
  fileprivate mutating func push<Value: ~Copyable>(_ value: consuming Value) -> PushResult<Value> {
    let candidate =
      cursor
      .alignedUp(for: Value.self)
    let nextCursor =
      candidate
      .advanced(by: MemoryLayout<Value>.size)
    guard nextCursor < (buffer.baseAddress! + buffer.count) else {
      return .value(value)
    }
    elementMetadata.append(ElementMetadata<Value>.self)
    cursor = nextCursor
    let pointer =
      candidate
      .bindMemory(to: Value.self, capacity: 1)
    pointer.initialize(to: value)
    return .pointer(pointer)
  }

  fileprivate mutating func reset() {
    deinitializeElements()
    elementMetadata.removeAll(keepingCapacity: true)
    cursor = buffer.baseAddress!
  }

  fileprivate init(
    byteCount: Int,
    alignment: Int
  ) {
    buffer = .allocate(byteCount: byteCount, alignment: alignment)
    cursor = buffer.baseAddress!
  }

  /// The cursor we expect given `elementMetadata`, mostly used for validation.
  private func computedCursor() -> UnsafeMutableRawPointer {
    var cursor = buffer.baseAddress!
    for metadata in elementMetadata {
      metadata.incrementCursor(&cursor, onElement: { _ in })
    }
    return cursor
  }

  private let buffer: UnsafeMutableRawBufferPointer
  private var cursor: UnsafeMutableRawPointer
  private var elementMetadata: [ElementMetadataProtocol.Type] = []

  private protocol ElementMetadataProtocol {
    static func incrementCursor(
      _ cursor: inout UnsafeMutableRawPointer,
      onElement: (UnsafeMutableRawPointer) -> Void
    )
    static func deinitializeElement(at pointer: UnsafeMutableRawPointer)
  }
  private enum ElementMetadata<Value: ~Copyable>: ElementMetadataProtocol {
    static func incrementCursor(
      _ cursor: inout UnsafeMutableRawPointer,
      onElement: (UnsafeMutableRawPointer) -> Void
    ) {
      let pointer =
        cursor
        .alignedUp(for: Value.self)
      onElement(cursor)
      cursor = pointer.advanced(by: MemoryLayout<Value>.size)
    }
    static func deinitializeElement(at pointer: UnsafeMutableRawPointer) {
      pointer.assumingMemoryBound(to: Value.self).deinitialize(count: 1)
    }
  }

  /// This does not change the value of `cursor`
  private func deinitializeElements() {
    var cursor = buffer.baseAddress!
    let endCursor = self.cursor
    for metadata in elementMetadata {
      metadata.incrementCursor(&cursor) { pointer in
        metadata.deinitializeElement(at: pointer)
      }
    }
    assert(cursor == endCursor)
  }

  deinit {
    deinitializeElements()
    buffer.deallocate()
  }

}
