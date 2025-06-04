struct VariadicTupleElementAccessor<Tuple, Element> {
  fileprivate let offset: Int

  func mutate<each TupleElement, T>(
    _ tuple: inout Tuple,
    _ body: (inout Element) throws -> T
  ) rethrows -> T
  where (repeat each TupleElement) == Tuple {
    try withUnsafeMutableBytes(of: &tuple) { buffer in
      assert(offset < buffer.count)
      let pointer = (buffer.baseAddress! + offset)
        .assumingMemoryBound(to: Element.self)
      return try body(&pointer.pointee)
    }
  }

}

func withVariadicTupleElementAccessors<each TupleElement, each Input, T>(
  for _: (repeat (each TupleElement).Type),
  input: (repeat each Input),
  transform: repeat (
    each Input,
    VariadicTupleElementAccessor<(repeat each TupleElement), each TupleElement>
  ) -> T
) -> [T] {
  var offsetCursor = 0

  func referenceNextElement<Element>() -> VariadicTupleElementAccessor<
    (repeat each TupleElement), Element
  > {
    let alignment = MemoryLayout<Element>.alignment
    let offset = (offsetCursor + alignment - 1) & ~(alignment - 1)
    offsetCursor = offset + MemoryLayout<Element>.size
    return VariadicTupleElementAccessor(offset: offset)
  }

  var results: [T] = []
  for (input, transform) in repeat (each input, each transform) {
    results.append(transform(input, referenceNextElement()))
  }
  return results
}

struct VariadicTupleArchetype<Tuple> {

  init<each TupleElement>() where Tuple == (repeat each TupleElement) {
    var elementAccessors: [Any] = []

    var offsetCursor = 0
    func referenceNextElement<Element>(
      _ type: Element.Type
    ) -> ElementAccessor<Element> {
      let alignment = MemoryLayout<Element>.alignment
      let offset = (offsetCursor + alignment - 1) & ~(alignment - 1)
      offsetCursor = offset + MemoryLayout<Element>.size
      return ElementAccessor(offset: offset)
    }

    let elementTypes = (repeat (each TupleElement).self)
    for elementType in repeat each elementTypes {
      elementAccessors.append(referenceNextElement(elementType))
    }
    self.elementAccessors = elementAccessors.makeIterator()
  }

  mutating func nextElementAccessor<Element>(
    of type: Element.Type = Element.self
  ) -> ElementAccessor<Element> {
    elementAccessors.next() as! ElementAccessor<Element>
  }

  struct ElementAccessor<Element> {

    func mutate<each TupleElement, T>(
      _ tuple: inout Tuple,
      _ body: (inout Element) throws -> T
    ) rethrows -> T
    where (repeat each TupleElement) == Tuple {
      try withUnsafeMutableBytes(of: &tuple) { buffer in
        assert(offset < buffer.count)
        let pointer = (buffer.baseAddress! + offset)
          .assumingMemoryBound(to: Element.self)
        return try body(&pointer.pointee)
      }
    }

    fileprivate let offset: Int
  }

  private var elementAccessors: [Any].Iterator

}
