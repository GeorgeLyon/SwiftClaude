struct VariadicTuple<Elements> {

  init<each Element>(_ values: repeat each Element) where Elements == (repeat each Element) {
    storage = Storage(repeat each values)
  }

  subscript<each Element, U>(
    _ accessor: VariadicTupleAccessor<Self, U>
  ) -> U
  where Elements == (repeat each Element) {
    storage.buffer.advanced(by: accessor.offset).assumingMemoryBound(to: U.self).pointee
  }

  static func accessors<each Element>() -> (repeat VariadicTupleAccessor<Self, each Element>)
  where Elements == (repeat each Element) {
    let layout = Storage<Elements>.layout()
    var offsetIterator = layout.offsets.makeIterator()
    func nextOffset<U>(_ type: U.Type) -> Int {
      return offsetIterator.next()!
    }
    return (repeat VariadicTupleAccessor(offset: nextOffset((each Element).self)))
  }

  func values<each Element>() -> (repeat each Element)
  where Elements == (repeat each Element) {
    let accessors = Self.accessors()
    return (repeat self[each accessors])
  }

  private let storage: Storage<Elements>

}

struct VariadicTupleAccessor<T, U> {
  let offset: Int
}

/// There is currently no way to create variadic tuple member accessors in Swift
/// This class heap-allocates a Tuple with a deterministic
private final class Storage<Elements> {

  init<each Element>(_ values: repeat each Element) where Elements == (repeat each Element) {
    let layout = Self.layout()
    let buffer = UnsafeMutableRawPointer.allocate(
      byteCount: layout.byteCount,
      alignment: layout.alignment
    )
    var offsetIterator = layout.offsets.makeIterator()
    for value in repeat each values {
      let offset = offsetIterator.next()!
      buffer
        .advanced(by: offset)
        .initializeMemory(as: type(of: value), to: value)
    }
    self.buffer = buffer
    self.deinitializeElements = { buffer in
      var offsetIterator = layout.offsets.makeIterator()
      for type in repeat (each Element).self {
        let offset = offsetIterator.next()!
        buffer
          .advanced(by: offset)
          .assumingMemoryBound(to: type)
          .deinitialize(count: 1)
      }
    }
  }

  deinit {
    deinitializeElements(buffer)
    buffer.deallocate()
  }

  let buffer: UnsafeMutableRawPointer

  /// `deinit` cannot introduce the `Element` pack, so element deinitialization
  /// is captured at initialization time, where the pack is in scope.
  private let deinitializeElements: (UnsafeMutableRawPointer) -> Void

  static func layout<each Element>() -> Layout
  where Elements == (repeat each Element) {
    var cursor = 0
    var layout = Layout()
    for elementLayout in repeat MemoryLayout<each Element>.self {
      let alignment = elementLayout.alignment
      cursor = (cursor + alignment - 1) & ~(alignment - 1)
      layout.offsets.append(cursor)
      cursor += elementLayout.size
      layout.alignment = max(alignment, layout.alignment)
    }
    layout.byteCount = cursor
    return layout
  }

}

private struct Layout {
  var offsets: [Int] = []
  var alignment: Int = 1
  var byteCount: Int = 0
}
