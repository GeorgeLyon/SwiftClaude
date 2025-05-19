import Collections

extension JSON {

  public struct UnicodeScalarBuffer: Sendable, ~Copyable {

    public init() {
    }

    public mutating func reset() {
      assert(readScalarsRetainCount == 0)
      readScalarsCount = 0
      droppedScalarsCount = 0
      scalars.removeAll(keepingCapacity: true)
    }

    public mutating func push(_ fragment: String) {
      scalars.append(contentsOf: fragment.unicodeScalars)
    }

    typealias SubSequence = Slice<Deque<UnicodeScalar>>

    mutating func readScalar() -> UnicodeScalar? {
      guard
        let scalar = readingScalars(
          count: 1,
          body: { scalars in
            assert(scalars.count == 1)
            return scalars.first!
          }
        )
      else {
        return nil
      }
      return scalar
    }

    mutating func readingScalars<T>(
      count: Int,
      body: (SubSequence) throws -> T
    ) rethrows -> T? {
      let scalars = readableScalars
      guard scalars.count >= count else {
        return nil
      }

      let result = try body(scalars.prefix(count))
      didReadScalars(count: count)
      return result
    }

    mutating func readingScalars<T>(
      until stopCondition: (UnicodeScalar) -> Bool,
      body: (SubSequence) throws -> T
    ) rethrows -> T {
      for index in readableScalars.indices {
        if stopCondition(readableScalars[index]) {
          let readScalars = readableScalars[..<index]
          let result = try body(readScalars)
          didReadScalars(count: readScalars.count)
          return result
        }
      }
      let readScalars = readableScalars
      let result = try body(readScalars)
      didReadScalars(count: readScalars.count)
      return result
    }

    mutating func readingScalars<T>(
      while condition: (UnicodeScalar) -> Bool,
      expectedCount: Int,
      body: (SubSequence) throws -> T
    ) rethrows -> T? {
      let readableScalars = readableScalars.prefix(expectedCount)
      for index in readableScalars.indices {
        guard condition(readableScalars[index]) else {
          let readScalars = readableScalars[..<index]
          let result = try body(readScalars)
          didReadScalars(count: readScalars.count)
          return result
        }
      }
      guard readableScalars.count == expectedCount else {
        /// If all scalars match the condition, but we didn't read enough, return nil
        return nil
      }
      let readScalars = readableScalars
      let result = try body(readScalars)
      didReadScalars(count: readScalars.count)
      return result
    }

    struct Checkpoint: ~Copyable {
      fileprivate let offset: Int

      consuming fileprivate func release() {
        discard self
      }

      deinit {
        assertionFailure()
      }
    }
    mutating func createCheckpoint() -> Checkpoint {
      readScalarsRetainCount += 1
      return Checkpoint(offset: readScalarsCount)
    }

    mutating func scalarsRead(
      since checkpoint: borrowing Checkpoint
    ) -> String {
      let startIndex = scalars.index(
        scalars.startIndex,
        offsetBy: checkpoint.offset - droppedScalarsCount
      )
      let readScalars = String(
        String.UnicodeScalarView(scalars[startIndex..<nextReadIndex])
      )
      return readScalars
    }

    mutating func restore(to checkpoint: consuming Checkpoint) {
      readScalarsCount = checkpoint.offset
      release(checkpoint)
    }

    mutating func discard(_ checkpoint: consuming Checkpoint) {
      release(checkpoint)
    }

    private var readableScalars: SubSequence {
      return scalars[nextReadIndex...]
    }

    private mutating func release(_ checkpoint: consuming Checkpoint) {
      checkpoint.release()
      readScalarsRetainCount -= 1
      assert(readScalarsRetainCount >= 0)
      if readScalarsRetainCount == 0 {
        scalars.removeFirst(readScalarsCount - droppedScalarsCount)
        droppedScalarsCount = readScalarsCount
      }
    }

    private mutating func didReadScalars(count: Int) {
      readScalarsCount += count
      if readScalarsRetainCount == 0 {
        droppedScalarsCount += count
        scalars.removeFirst(count)
      }
    }

    private var nextReadIndex: SubSequence.Index {
      scalars.index(
        scalars.startIndex,
        offsetBy: readScalarsCount - droppedScalarsCount
      )
    }

    private var droppedScalarsCount = 0
    private var readScalarsCount = 0
    private var readScalarsRetainCount = 0
    private var scalars = Deque<UnicodeScalar>()

  }

}
