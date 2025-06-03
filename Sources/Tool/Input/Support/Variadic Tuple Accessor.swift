struct VariadicTupleAccessor<each Element>: Sendable {

  init() {
    var offsetCursor = 0
    func referenceNextElement<T>(as type: T.Type) -> ElementReference<T> {
      let alignment = MemoryLayout<T>.alignment
      let offset = (offsetCursor + alignment - 1) & ~(alignment - 1)
      offsetCursor = offset
      return ElementReference(offset: offset)
    }
    elementReferences = (repeat referenceNextElement(as: (each Element).self))
  }

  let elementReferences: (repeat ElementReference<each Element>)

  struct ElementReference<T> {
    fileprivate let offset: Int
  }
  func mutate<T, Result>(
    _ reference: ElementReference<T>,
    on tuple: inout (repeat each Element),
    body: (inout T) throws -> Result
  ) rethrows -> Result {
    try withUnsafeMutableBytes(of: &tuple) { buffer in
      assert(reference.offset < buffer.count)
      let pointer = (buffer.baseAddress! + reference.offset)
        .assumingMemoryBound(to: T.self)
      return try body(&pointer.pointee)
    }
  }

}
