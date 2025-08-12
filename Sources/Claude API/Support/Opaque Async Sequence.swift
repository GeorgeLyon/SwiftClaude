extension Claude {

  /// A protocol that allows us to vent opaque async sequences
  /// This should no longer be necessary once this is fixed:
  /// https://forums.swift.org/t/pitch-generalize-asyncsequence-and-asynciteratorprotocol/69283/23
  public protocol OpaqueAsyncSequence<Element>: AsyncSequence where Failure == Error {

  }

}

extension AsyncSequence {

  var opaque: some Claude.OpaqueAsyncSequence<Element> {
    return ConcreteOpaqueAsyncSequence(base: self)
  }

}

private struct ConcreteOpaqueAsyncSequence<Base: AsyncSequence>: Claude.OpaqueAsyncSequence {

  struct AsyncIterator: AsyncIteratorProtocol {
    mutating func next() async throws -> Base.Element? {
      try await base.next()
    }
    mutating func next(
      isolation actor: isolated (any Actor)?
    ) async throws(Base.Failure) -> Element? {
      try await base.next(isolation: actor)
    }
    fileprivate init(base: Base) {
      self.base = base.makeAsyncIterator()
    }
    private var base: Base.AsyncIterator
  }
  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(base: base)
  }
  let base: Base
}
