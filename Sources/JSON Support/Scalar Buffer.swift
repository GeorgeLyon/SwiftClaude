import Collections

extension JSON {

  public struct ScalarBuffer: Sendable, ~Copyable {

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

    /// - warning: SubSequences are invalidated if the buffer is modified
    typealias SubSequence = Slice<Deque<UnicodeScalar>>

    var readableScalars: SubSequence {
      return scalars[nextReadIndex...]
    }

    mutating func readScalar() -> UnicodeScalar? {
      guard let scalars = readScalars(count: 1) else {
        return nil
      }
      assert(scalars.count == 1)
      return scalars.first!
    }

    mutating func readScalars(count: Int) -> SubSequence? {
      let scalars = readableScalars
      guard scalars.count >= count else {
        return nil
      }

      readScalarsCount += count
      let endIndex = scalars.index(
        scalars.startIndex,
        offsetBy: count
      )
      return scalars[..<endIndex]
    }

    mutating func readScalars(
      until stopCondition: (UnicodeScalar) -> Bool
    ) -> SubSequence {
      for index in readableScalars.indices {
        if stopCondition(readableScalars[index]) {
          let readBytes = readableScalars[..<index]
          readScalarsCount += readBytes.count
          return readBytes
        }
      }
      let readScalars = readableScalars
      readScalarsCount += readScalars.count
      return readScalars
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

    private mutating func release(_ checkpoint: consuming Checkpoint) {
      checkpoint.release()
      readScalarsRetainCount -= 1
      assert(readScalarsRetainCount >= 0)
      if readScalarsRetainCount == 0 {
        scalars.removeFirst(readScalarsCount - droppedScalarsCount)
        droppedScalarsCount = readScalarsCount
      }
    }

    private mutating func didReadScalars(_ count: Int) {
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
