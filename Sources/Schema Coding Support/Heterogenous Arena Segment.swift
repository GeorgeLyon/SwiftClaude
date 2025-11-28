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
      byteCount: max(MemoryLayout<Value>.size, 4096),
      alignment: max(MemoryLayout<Value>.alignment, MemoryLayout<Int>.alignment)
    )
    guard case .pointer(let pointer) = slab.push(value) else {
      fatalError()
    }
    slabs.append(slab)
    return pointer
  }

  private var slabs: UniqueArray<HeterogenousSlab> = .init()
  private var emptySlabs: UniqueArray<HeterogenousSlab> = .init()

}

struct HeterogenousSlab: ~Copyable {

  fileprivate enum PushResult<Value: ~Copyable>: ~Copyable {
    case pointer(UnsafeMutablePointer<Value>)
    case value(Value)
  }
  fileprivate mutating func push<Value: ~Copyable>(_ value: consuming Value) -> PushResult<Value> {
    let metadataCandidate =
      cursor
      .alignedUp(for: (any ElementMetadataProtocol).self)
    let valueCandidate =
      metadataCandidate
      .advanced(by: MemoryLayout<any ElementMetadataProtocol>.size)
      .alignedUp(for: Value.self)
    let nextCursor =
      valueCandidate
      .advanced(by: MemoryLayout<Value>.size)
    guard nextCursor < (buffer.baseAddress! + buffer.count) else {
      return .value(value)
    }
    metadataCandidate
      .bindMemory(to: (any ElementMetadataProtocol).self, capacity: 1)
      .initialize(to: ElementMetadata<Value>())
    let pointer =
      valueCandidate
      .bindMemory(to: Value.self, capacity: 1)
    pointer.initialize(to: value)
    return .pointer(pointer)
  }

  fileprivate mutating func reset() {
    deinitializeElements()
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

  private protocol ElementMetadataProtocol {
    func deinitializeElement(advancing cursor: inout UnsafeMutableRawPointer)
  }
  private struct ElementMetadata<Value: ~Copyable>: ElementMetadataProtocol {
    func deinitializeElement(advancing cursor: inout UnsafeMutableRawPointer) {
      let pointer =
        cursor
        .alignedUp(for: Value.self)
      pointer.assumingMemoryBound(to: Value.self).deinitialize(count: 1)
      cursor = pointer.advanced(by: MemoryLayout<Value>.size)
    }
  }

  /// This does not change the value of `cursor`
  private func deinitializeElements() {
    var cursor = buffer.baseAddress!
    let endCursor = self.cursor
    while cursor < endCursor {
      let metadataPointer =
        cursor
        .assumingMemoryBound(to: (any ElementMetadataProtocol).self)
      metadataPointer.pointee.deinitializeElement(advancing: &cursor)
    }
    assert(cursor == endCursor)
  }

  deinit {
    deinitializeElements()
    buffer.deallocate()
  }

}
