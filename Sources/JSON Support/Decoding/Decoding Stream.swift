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

    mutating func readCharacter() -> Character? {
      let readableSubstring = readableSubstring
      guard let character = readableSubstring.first else {
        return nil
      }
      nextReadIndex = readableSubstring.index(after: nextReadIndex)
      return character
    }

    enum ReadResult<T> {
      case matched(T)
      case continuableMatch
      case notMatched(Swift.Error)
    }

    mutating func read(_ string: String) -> ReadResult<Void> {
      var expectedCharacters = string.makeIterator()
      return read(
        while: { $0 == expectedCharacters.next() },
        minCount: string.count,
        maxCount: string.count
      ) { _ in }
    }

    struct CharacterCondition: ExpressibleByUnicodeScalarLiteral {

      init(unicodeScalarLiteral value: Character) {
        range = value...value
      }

      fileprivate init(range: ClosedRange<Character>) {
        self.range = range
      }

      fileprivate let range: ClosedRange<Character>
    }

    mutating func read<T>(
      whileCharactersIn acceptedCharacters: CharacterCondition...,
      minCount: Int? = nil,
      maxCount: Int? = nil,
      read: (Substring) throws -> T
    ) rethrows -> ReadResult<T> {
      try self.read(
        while: { acceptedCharacters.accepts($0) },
        minCount: minCount,
        maxCount: maxCount,
        read: read
      )
    }

    mutating func read<T>(
      untilCharacterIn terminationCharacters: CharacterCondition...,
      minCount: Int? = nil,
      maxCount: Int? = nil,
      read: (Substring) throws -> T
    ) rethrows -> ReadResult<T> {
      try self.read(
        while: { !terminationCharacters.accepts($0) },
        minCount: minCount,
        maxCount: maxCount,
        read: read
      )
    }

    private mutating func read<T>(
      while acceptCondition: (Character) -> Bool,
      minCount: Int? = nil,
      maxCount: Int? = nil,
      read: (Substring) throws -> T
    ) rethrows -> ReadResult<T> {
      let readableSubstring = readableSubstring
      let endIndex: String.Index
      let continuableMatch: Bool

      var readCount = 0
      reading: do {
        let indices = readableSubstring.indices
        for index in indices {
          let character = readableSubstring[index]
          guard acceptCondition(character) else {
            endIndex = index
            continuableMatch = false
            break reading
          }
          readCount += 1

          if let maxCount {
            guard readCount < maxCount else {
              endIndex = readableSubstring.index(after: index)
              continuableMatch = false
              break reading
            }
          }
        }
        endIndex = readableSubstring.endIndex
        continuableMatch = true
      }

      if let minCount {
        guard readCount >= minCount else {
          if continuableMatch {
            return .continuableMatch
          } else {
            return .notMatched(
              Error.unexpectedCharacter(at: endIndex)
            )
          }
        }
      }

      let result = try read(readableSubstring[..<endIndex])
      nextReadIndex = endIndex
      return .matched(result)
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
    case unexpectedCharacter(at: String.Index)
  }

}

func ... (lhs: Character, rhs: Character) -> JSON.DecodingStream.CharacterCondition {
  JSON.DecodingStream.CharacterCondition(range: lhs...rhs)
}

extension Array where Element == JSON.DecodingStream.CharacterCondition {
  fileprivate func accepts(_ character: Character) -> Bool {
    return contains { condition in
      condition.range.contains(character)
    }
  }
}
