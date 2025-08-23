struct VariadicTupleArchetype<each Element> {

  typealias ElementAccessors = (repeat ElementAccessor<each Element>)

  init() {
    var offsetCursor = 0
    func nextElementAccessor<T>(
      _ type: T.Type
    ) -> ElementAccessor<T> {
      let alignment = MemoryLayout<T>.alignment
      let offset = (offsetCursor + alignment - 1) & ~(alignment - 1)
      offsetCursor = offset + MemoryLayout<T>.size
      return ElementAccessor(offset: offset)
    }
    self.elementAccessors = (repeat nextElementAccessor((each Element).self))
  }

  struct ElementAccessor<AccessedElement> {

    func getValue(
      from tuple: (repeat each Element)
    ) -> AccessedElement {
      withUnsafeBytes(of: tuple) { buffer in
        assert(offset < buffer.count)
        let pointer = (buffer.baseAddress! + offset)
          .assumingMemoryBound(to: AccessedElement.self)
        return pointer.pointee
      }
    }

    func mutate<T>(
      _ tuple: inout (repeat each Element),
      _ body: (inout AccessedElement) throws -> T
    ) rethrows -> T {
      try withUnsafeMutableBytes(of: &tuple) { buffer in
        assert(offset < buffer.count)
        let pointer = (buffer.baseAddress! + offset)
          .assumingMemoryBound(to: AccessedElement.self)
        return try body(&pointer.pointee)
      }
    }

    fileprivate let offset: Int
  }

  let elementAccessors: ElementAccessors

}
