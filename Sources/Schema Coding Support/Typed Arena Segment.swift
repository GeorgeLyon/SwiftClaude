private import BasicContainers

protocol TypedArenaSegmentProtocol {
  func reset()
}

final class TypedArenaSegment<Value: ~Copyable>: TypedArenaSegmentProtocol {

  init(slabCapacity: Int) {
    self.slabCapacity = slabCapacity
  }

  func push(_ value: consuming Value) -> UnsafeMutablePointer<Value> {
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

  func reset() {
    while !slabs.isEmpty {
      var slab = slabs.removeLast()
      slab.reset()
      emptySlabs.append(slab)
    }
  }

  private func pushToEmptySlab(
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
    var slab = TypedArenaSlab<Value>(
      capacity: slabCapacity
    )
    guard case .pointer(let pointer) = slab.push(value) else {
      fatalError()
    }
    slabs.append(slab)
    return pointer
  }

  private let slabCapacity: Int
  private var slabs: UniqueArray<TypedArenaSlab<Value>> = .init()
  private var emptySlabs: UniqueArray<TypedArenaSlab<Value>> = .init()

}

private struct TypedArenaSlab<Value: ~Copyable>: ~Copyable {

  enum PushResult: ~Copyable {
    case pointer(UnsafeMutablePointer<Value>)
    case value(Value)
  }
  mutating func push(_ value: consuming Value) -> PushResult {
    guard count < buffer.count else {
      return .value(value)
    }
    let pointer = buffer.baseAddress! + count
    pointer.initialize(to: value)
    count += 1
    return .pointer(pointer)
  }

  mutating func reset() {
    deinitializeElements()
    count = 0
  }

  init(
    capacity: Int
  ) {
    self.buffer = .allocate(capacity: capacity)
  }

  private let buffer: UnsafeMutableBufferPointer<Value>
  private var count = 0

  private func deinitializeElements() {
    buffer.baseAddress!.deinitialize(count: count)
  }

  deinit {
    deinitializeElements()
    buffer.deallocate()
  }
}
