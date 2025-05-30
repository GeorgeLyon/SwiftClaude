extension JSON {

  public struct DecodingStream: Sendable, ~Copyable {

    public init() {
      nextReadIndex = string.startIndex
    }

    public mutating func reset() {
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

    public struct Checkpoint {
      fileprivate let index: String.Index
    }
    public mutating func createCheckpoint() -> Checkpoint {
      return Checkpoint(index: nextReadIndex)
    }

    public func substringDecoded(
      since checkpoint: borrowing Checkpoint
    ) -> Substring {
      string[checkpoint.index..<nextReadIndex]
    }

    /// We depend on `String.Index` not being invalidated when appending to the string.
    /// This should be safe as long as we don't use `endIndex` (which could end up pointing to the middle of a grapheme cluster due to combining diacritics and `ZWJ`).
    private var nextReadIndex: String.Index

    private var string = ""

  }

}

// MARK: - Reading from the stream

extension JSON.DecodingStream {

  mutating func readCharacter() -> ReadResult<Character> {
    let readableSubstring = readableSubstring
    guard let character = readableSubstring.first else {
      if isFinished {
        return .notMatched(Error.unexpectedEndOfStream)
      } else {
        return .needsMoreData
      }
    }
    nextReadIndex = readableSubstring.index(after: nextReadIndex)
    return .matched(character)
  }

  /// Peeks at the next character but does not increment the read index.
  /// If `body` returns `nil`, returns an `error` result.
  func peekCharacter<T>(
    _ body: (Character) -> T?
  ) -> ReadResult<T> {
    let readableSubstring = readableSubstring
    guard let character = readableSubstring.first else {
      if isFinished {
        return .notMatched(Error.unexpectedEndOfStream)
      } else {
        return .needsMoreData
      }
    }
    guard let result = body(character) else {
      return .notMatched(Error.unexpectedCharacter(character, at: nextReadIndex))
    }
    return .matched(result)
  }

  /// Reads a single character only if `body` returns a non-nil value.
  mutating func readCharacter<T>(
    _ body: (Character) -> T?
  ) -> ReadResult<T> {
    let result = peekCharacter(body)
    if case .matched = result {
      nextReadIndex = readableSubstring.index(after: nextReadIndex)
    }
    return result
  }

  mutating func read(_ string: String) -> ReadResult<Void> {
    var expectedCharacters = string.makeIterator()
    return read(
      while: { $0 == expectedCharacters.next() },
      minCount: string.count,
      maxCount: string.count,
      processPartialMatchAtEndOfBuffer: false,
    ) { _, _ in }
  }

  mutating func read(
    whileCharactersIn acceptedCharacters: CharacterCondition...,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    processPartialMatchAtEndOfBuffer: Bool = false,
  ) -> ReadResult<Void> {
    self.read(
      while: { acceptedCharacters.accepts($0) },
      minCount: minCount,
      maxCount: maxCount,
      processPartialMatchAtEndOfBuffer: processPartialMatchAtEndOfBuffer,
      process: { _, _ in }
    )
  }

  mutating func read(
    untilCharacterIn terminationCharacters: CharacterCondition...,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    processPartialMatchAtEndOfBuffer: Bool = false,
  ) -> ReadResult<Void> {
    self.read(
      while: { !terminationCharacters.accepts($0) },
      minCount: minCount,
      maxCount: maxCount,
      processPartialMatchAtEndOfBuffer: processPartialMatchAtEndOfBuffer,
      process: { _, _ in }
    )
  }

  mutating func read<T>(
    whileCharactersIn acceptedCharacters: CharacterCondition...,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    processPartialMatchAtEndOfBuffer: Bool = false,
    process: (inout Substring, Character?) throws -> T
  ) rethrows -> ReadResult<T> {
    try self.read(
      while: { acceptedCharacters.accepts($0) },
      minCount: minCount,
      maxCount: maxCount,
      processPartialMatchAtEndOfBuffer: processPartialMatchAtEndOfBuffer,
      process: process
    )
  }

  mutating func read<T>(
    untilCharacterIn terminationCharacters: CharacterCondition...,
    minCount: Int? = nil,
    maxCount: Int? = nil,
    processPartialMatchAtEndOfBuffer: Bool = false,
    process: (inout Substring, Character?) throws -> T
  ) rethrows -> ReadResult<T> {
    try self.read(
      while: { !terminationCharacters.accepts($0) },
      minCount: minCount,
      maxCount: maxCount,
      processPartialMatchAtEndOfBuffer: processPartialMatchAtEndOfBuffer,
      process: process
    )
  }

  private mutating func read<T>(
    while acceptCondition: (Character) -> Bool,
    minCount: Int?,
    maxCount: Int?,
    processPartialMatchAtEndOfBuffer: Bool,
    process: (inout Substring, Character?) throws -> T
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

      if isFinished {
        continuableMatch = false
      } else {
        continuableMatch = !processPartialMatchAtEndOfBuffer
      }
    }

    if let minCount {
      guard readCount >= minCount else {
        if continuableMatch {
          return .needsMoreData
        } else if endIndex < readableSubstring.endIndex {
          return .notMatched(
            Error.unexpectedCharacter(readableSubstring[endIndex], at: endIndex)
          )
        } else {
          return .notMatched(
            Error.unexpectedEndOfStream
          )
        }
      }
    }

    guard !continuableMatch else {
      return .needsMoreData
    }

    var substring = readableSubstring[..<endIndex]
    let terminatingCharacter =
      endIndex < readableSubstring.endIndex ? readableSubstring[endIndex] : nil
    let result = try process(&substring, terminatingCharacter)
    nextReadIndex = substring.endIndex
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

  mutating func restore(_ checkpoint: consuming Checkpoint) {
    nextReadIndex = checkpoint.index
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

}

// MARK: - Result Types

extension JSON {

  public enum DecodingResult<Value: ~Copyable>: ~Copyable {
    case needsMoreData
    case decoded(Value)

    public consuming func getValue() throws -> Value {
      switch consume self {
      case .needsMoreData:
        throw Error.needsMoreData
      case .decoded(let value):
        return value
      }
    }

    public var needsMoreData: Bool {
      switch self {
      case .needsMoreData:
        return true
      case .decoded:
        return false
      }
    }

    consuming func map<T>(
      _ transform: (consuming Value) throws -> T
    ) rethrows -> DecodingResult<T> {
      switch consume self {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(let value):
        return .decoded(try transform(value))
      }
    }
  }

}

extension JSON.DecodingResult: Copyable where Value: Copyable {}

/// The result of reading data from the stream.
/// Similar to a `DecodingResult` but it returns errors as a separate case.
/// This is because we expect the "didn't match" case to happen on the happy path, and don't want to trip error breakpoints when this happens.
enum ReadResult<T> {
  case matched(T)
  case needsMoreData
  case notMatched(Swift.Error)
}

extension ReadResult {

  var needsMoreData: Bool {
    get throws {
      switch self {
      case .matched:
        return false
      case .needsMoreData:
        return true
      case .notMatched(let error):
        throw error
      }
    }
  }

  func decodingResult() throws -> JSON.DecodingResult<T> {
    switch self {
    case .matched(let value):
      return .decoded(value)
    case .needsMoreData:
      return .needsMoreData
    case .notMatched(let error):
      throw error
    }
  }

}

// MARK: - Character Conditions

struct CharacterCondition: ExpressibleByUnicodeScalarLiteral {
  init(unicodeScalarLiteral value: Character) {
    range = value...value
  }
  fileprivate init(range: ClosedRange<Character>) {
    self.range = range
  }
  fileprivate let range: ClosedRange<Character>
}

func ... (lhs: Character, rhs: Character) -> CharacterCondition {
  CharacterCondition(range: lhs...rhs)
}

extension Array where Element == CharacterCondition {
  fileprivate func accepts(_ character: Character) -> Bool {
    return contains { condition in
      condition.range.contains(character)
    }
  }
}

// MARK: - Implementation Details

private enum Error: Swift.Error {
  case needsMoreData
  case unexpectedCharacter(Character, at: String.Index)
  case unexpectedEndOfStream
  case numberWithLeadingZeroes
}
