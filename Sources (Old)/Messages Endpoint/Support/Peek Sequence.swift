/// A sequence with the ability to peek at the next element in the wrapped sequence
/// This is mainly used to implement cache breakpoints, which affect the encoding of the preceding element.
struct PeekSequence<Wrapped: Sequence>: Sequence {
  struct Iterator: IteratorProtocol {
    mutating func next() -> (next: Wrapped.Element, peek: Wrapped.Element?)? {
      guard let nextElement else {
        return nil
      }
      let incomingNext = remainder.next()
      let next = (next: nextElement, peek: incomingNext)
      self.nextElement = incomingNext
      return next
    }

    init(_ wrapped: Wrapped.Iterator) {
      self.remainder = wrapped
      self.nextElement = remainder.next()
    }
    private var nextElement: Wrapped.Element?
    private var remainder: Wrapped.Iterator
  }
  func makeIterator() -> Iterator {
    Iterator(wrapped.makeIterator())
  }
  init(_ wrapped: Wrapped) {
    self.wrapped = wrapped
  }
  private let wrapped: Wrapped
}
