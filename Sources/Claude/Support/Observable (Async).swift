import Observation

extension Observable {

  func untilNotNil<T>(
    _ keyPath: WritableKeyPath<Self, Result<T, Error>?>,
    isolation: isolated Actor = #isolation
  ) async throws -> T {
    let changes = AsyncStream<Void>.makeStream()
    var changesIterator = changes.stream.makeAsyncIterator()

    repeat {
      let value: Result<T, Error>?
      do {
        /// If this is deinitialized because the observed object is released, releasing the `onChange` closure without calling it, it wil finish the stream.
        let continuation = ContinuationThatFinishesIfItDidntYield(
          wrapped: changes.continuation
        )
        value = withObservationTracking {
          self[keyPath: keyPath]
        } onChange: {
          continuation.yield()
        }
      }

      if let value {
        return try value.get()
      } else {
        continue
      }
    } while await changesIterator.next() != nil
    throw CancellationError()
  }

}

struct ObservableAppendOnlyCollectionPropertyStream<Root: Observable, Elements: Collection>:
  Claude.OpaqueAsyncSequence
{

  typealias Element = Elements.SubSequence

  struct AsyncIterator: AsyncIteratorProtocol {

    mutating func next() async throws -> Elements.SubSequence? {
      try await next(isolation: nil)
    }

    mutating func next(
      isolation actor: isolated Actor?
    ) async throws -> Elements.SubSequence? {
      let changes = AsyncStream<Void>.makeStream()
      var changesIterator = changes.stream.makeAsyncIterator()

      repeat {
        let elements: Elements
        let result: Result<Void, Error>?

        do {
          /// If this is deinitialized because the observed object is released, releasing the `onChange` closure without calling it, it wil finish the stream.
          let continuation = ContinuationThatFinishesIfItDidntYield(
            wrapped: changes.continuation
          )
          (elements, result) = withObservationTracking {
            (root[keyPath: elementsKeyPath], root[keyPath: resultKeyPath])
          } onChange: {
            continuation.yield()
          }
        }

        let newEndIndex = elements.endIndex
        if lastEndIndex > newEndIndex {
          throw EndIndexDecreased()
        } else if lastEndIndex == newEndIndex {
          if let result {
            /// The stream is complete
            try result.get()
            return nil
          } else {
            /// Wait for the next change
            continue
          }
        } else {
          defer { lastEndIndex = newEndIndex }
          return elements[lastEndIndex..<newEndIndex]
        }
      } while await changesIterator.next() != nil

      /// The observed values (and thus the observation closure) were released
      throw CancellationError()
    }

    fileprivate init(
      root: Root,
      elementsKeyPath: KeyPath<Root, Elements>,
      resultKeyPath: KeyPath<Root, Result<Void, Error>?>
    ) {
      self.root = root
      self.elementsKeyPath = elementsKeyPath
      self.resultKeyPath = resultKeyPath
      self.lastEndIndex = root[keyPath: elementsKeyPath].startIndex
    }
    private let root: Root
    private let elementsKeyPath: KeyPath<Root, Elements>
    private let resultKeyPath: KeyPath<Root, Result<Void, Error>?>
    private var lastEndIndex: Elements.Index

    private struct EndIndexDecreased: Error {}
  }
  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(
      root: root,
      elementsKeyPath: elementsKeyPath,
      resultKeyPath: resultKeyPath
    )
  }

  init(
    root: Root,
    elementsKeyPath: KeyPath<Root, Elements>,
    resultKeyPath: KeyPath<Root, Result<Void, Error>?>
  ) {
    self.root = root
    self.elementsKeyPath = elementsKeyPath
    self.resultKeyPath = resultKeyPath
  }
  private let root: Root
  private let elementsKeyPath: KeyPath<Root, Elements>
  private let resultKeyPath: KeyPath<Root, Result<Void, Error>?>
}

/// A simple continuation that either yields, or finishes
private actor ContinuationThatFinishesIfItDidntYield: Sendable {

  init(wrapped: AsyncStream<Void>.Continuation) {
    self.wrapped = wrapped
  }

  deinit {
    wrapped?.finish()
  }

  nonisolated func yield() {
    Task {
      await self.doYield()
    }
  }

  private func doYield() {
    guard let wrapped else {
      assertionFailure()
      return
    }
    wrapped.yield()
    self.wrapped = nil
  }

  private var wrapped: AsyncStream<Void>.Continuation?
}
