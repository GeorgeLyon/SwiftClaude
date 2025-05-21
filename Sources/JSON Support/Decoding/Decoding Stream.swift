import Collections

extension JSON {

  public struct DecodingStream: Sendable, ~Copyable {

    public init() {
      nextReadIndex = string.startIndex
    }

    public mutating func reset() {
      assert(checkpointsCount == 0)
      string.unicodeScalars.removeAll(keepingCapacity: true)
      nextReadIndex = string.startIndex
      isFinished = false
    }

    public private(set) var isFinished = false

    public mutating func finish() {
      assert(!isFinished)
      isFinished = true
    }

    public mutating func push(_ fragment: String) {
      assert(!isFinished)
      string.append(fragment)
    }

    enum ReadStringResult {
      case read
      case needMoreData
      case notFound(Swift.Error)
    }
    mutating func read(_ string: String) -> ReadStringResult {
      let candidate = readableSubstring.prefix(string.count)
      let mismatch =
        zip(
          zip(string.indices, candidate.indices),
          zip(string, candidate)
        )
        .first(where: { $0.1.0 != $0.1.1 })
      if let mismatch {
        return .notFound(
          Error.unexpectedCharacter(
            expected: mismatch.1.0,
            observed: mismatch.1.1,
            at: mismatch.0.1
          )
        )
      }
      if candidate.count == string.count {
        nextReadIndex = candidate.endIndex
        return .read
      } else {
        /// The prefix matches, but the string is incomplete
        return .needMoreData
      }
    }

    mutating func readCharacter() -> Character? {
      read(count: 1) { substring in
        assert(substring.count == 1)
        return substring.first!
      }
    }

    mutating func read<T>(
      count: Int,
      _ body: (Substring) throws -> T
    ) rethrows -> T? {
      let substring = readableSubstring.prefix(count)
      guard substring.count == count else {
        return nil
      }
      let result = try body(substring)
      nextReadIndex = substring.endIndex
      return result
    }

    /// The read is only committed if `body` returns a non-nil value.
    mutating func read<T>(
      until stopCondition: (Character) -> Bool,
      maxCount: Int? = nil,
      _ body: (_ substring: Substring, _ conditionMet: Bool) throws -> T?
    ) rethrows -> T? {
      let readableSubstring =
        if let maxCount {
          readableSubstring.prefix(maxCount)
        } else {
          readableSubstring
        }
      for index in readableSubstring.indices {
        guard !stopCondition(readableSubstring[index]) else {
          let substring = readableSubstring[..<index]
          if let result = try body(substring, true) {
            nextReadIndex = substring.endIndex
            return result
          } else {
            return nil
          }
        }
      }
      if let result = try body(readableSubstring, false) {
        nextReadIndex = readableSubstring.endIndex
        return result
      } else {
        return nil
      }
    }

    /// Read characters while the condition is true.
    /// The read is only committed if `body` return `true`.
    mutating func read(
      until stopCondition: (Character) -> Bool,
      maxCount: Int? = nil,
      _ body: (_ substring: Substring, _ conditionMet: Bool) throws -> Bool
    ) rethrows {
      try read(until: stopCondition, maxCount: maxCount) { (substring, conditionMet) -> Void? in
        if try body(substring, conditionMet) {
          return ()
        } else {
          return nil
        }
      }
    }

    var possiblyIncompleteIncomingGraphemeCluster: Character? {
      if isFinished {
        return nil
      } else {
        return string.last
      }
    }

    mutating func readWhitespace() {
      nextReadIndex =
        readableSubstring
        .prefix { character in
          switch character {
          case " ", "\t", "\n", "\r":
            return true
          default:
            return false
          }
        }
        .endIndex
    }

    struct Checkpoint: ~Copyable {
      fileprivate let index: String.Index

      consuming fileprivate func release() {
        discard self
      }

      deinit {
        assertionFailure()
      }
    }
    mutating func createCheckpoint() -> Checkpoint {
      checkpointsCount += 1
      return Checkpoint(index: nextReadIndex)
    }

    mutating func stringRead(
      since checkpoint: borrowing Checkpoint
    ) -> Substring {
      string[checkpoint.index..<nextReadIndex]
    }

    mutating func restore(to checkpoint: consuming Checkpoint) {
      nextReadIndex = checkpoint.index
      release(checkpoint)
    }

    mutating func discard(_ checkpoint: consuming Checkpoint) {
      release(checkpoint)
    }

    private mutating func release(_ checkpoint: consuming Checkpoint) {
      checkpoint.release()
      checkpointsCount -= 1
      assert(checkpointsCount >= 0)
    }

    private var readableSubstring: Substring {
      if isFinished {
        return string[nextReadIndex...]
      } else {
        /**
         If the string is incomplete, the last character may be changed by subsequent unicode scalars.
         For example, the incomplete string `fac` may become `facts` or `façade` depending on future unicode scalars; also, emojis can be modified by a `ZWJ`.
         This can change the meaning of the string, and make `endIndex` invalid.
         To solve this, we do not consider the last character readable until the stream is complete.
         */
        return string[nextReadIndex...].dropLast()
      }
    }

    /// We depend on `String.Index` not being invalidated when appending to the string.
    /// This should be safe as long as we don't use `endIndex` (which could end up pointing to the middle of a grapheme cluster).
    private var nextReadIndex: String.Index

    private var string = ""
    private var checkpointsCount = 0

  }

  private enum Error: Swift.Error {
    case unexpectedCharacter(expected: Character, observed: Character, at: String.Index)
  }

}
