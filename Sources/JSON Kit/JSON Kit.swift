private struct JSONValueReader<Fragments: AsyncSequence<String, Error>>: ~Copyable {

  mutating func readStringFragments<T>(
    _ body: (
      inout JSONStringFragmentReader<Fragments>,
      isolated (any Actor)?
    ) async throws -> sending T,
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> T {
    try await stream.readJSONStringFragments(body)
  }

  mutating func readString(
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> String {
    try await stream.readJSONString()
  }

  var stream: CharacterStream<Fragments>

}

private struct JSONObjectPropertyReader<Fragments: AsyncSequence<String, Error>>: ~Copyable {

  fileprivate init(stream: consuming CharacterStream<Fragments>) {
    self.stream = stream
  }

  private var stream: CharacterStream<Fragments>

}

private struct JSONObjectPropertyListReader<Fragments: AsyncSequence<String, Error>>: ~Copyable {

  mutating func readNextProperty<T>(
    _ body: (
      borrowing JSONObjectPropertyReader<Fragments>,
      isolated (any Actor)?
    ) async throws -> T,
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> T? {
    guard !isComplete else {
      assertionFailure()
      return nil
    }

    switch try await stream.read(oneOf: ",", "}") {
    case ",":
      let name = try await stream.readJSONString()
      try await stream.read(":")

    case "}":
      isComplete = true
      return nil
    default:
      throw ErrorToBeSpecialized()
    }
    fatalError()
  }

  fileprivate init(stream: consuming CharacterStream<Fragments>) {
    self.stream = stream
  }

  private var isComplete = false
  private var stream: CharacterStream<Fragments>

}

private struct JSONStringFragmentReader<Fragments: AsyncSequence<String, Error>>: ~Copyable {

  mutating func readNextFragment(
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> String? {
    guard !isComplete else {
      return nil
    }

    try await stream.fillBufferUntilNonempty()

    var scalars = trailingGraphemeCluster
    while let next = stream.readNextCharacterIfReady() {
      if isNextCharacterEscaped {
        /// Handle escape sequences
        switch next {
        /// Ignored characters
        case "b", "r", "f":
          break
        /// Verbatim characters
        case "\"":
          scalars.append("\"")
        case "\\":
          scalars.append("\\")
        case "/":
          scalars.append("/")
        /// Escaped characters
        case "n":
          scalars.append("\n")
        case "t":
          scalars.append("\t")
        case "u":
          let stringValue = try await stream.peekString(count: 4)

          guard
            let intValue = Int(stringValue, radix: 16)
          else {
            throw ErrorToBeSpecialized()
          }

          switch intValue {

          /// Handle UTF-16 surrogate pairs
          case 0xDC00...0xDFFF:
            /// Low surrogate value without corresponding high surrogate value
            throw ErrorToBeSpecialized()
          case 0xD800...0xDBFF:

            // The buffer should contain HHHH\uLLLL with LLLL being the low part of the surrogate pair
            let additionalStringValue = try await stream.peekString(count: 10)

            guard additionalStringValue.dropFirst(4).prefix(2) == "\\u" else {
              throw ErrorToBeSpecialized()
            }

            guard
              let lowIntValue = Int(additionalStringValue.dropFirst(6)),
              (0xDC00...0xDFFF).contains(lowIntValue),
              let scalar = UnicodeScalar(
                [
                  0x10000,
                  ((intValue - 0xD800) << 10),
                  lowIntValue - 0xDC00,
                ].reduce(0, +)
              )
            else {
              throw ErrorToBeSpecialized()
            }

            stream.readPeekedString(count: 10)
            scalars.append(scalar)
          default:
            guard let scalar = UnicodeScalar(intValue) else {
              throw ErrorToBeSpecialized()
            }
            stream.readPeekedString(count: 4)
            scalars.append(scalar)
          }

        default:
          throw ErrorToBeSpecialized()
        }
        isNextCharacterEscaped = false
      } else if !isNextCharacterEscaped {
        switch next {
        case "\\":
          isNextCharacterEscaped = true
        case "\"":
          isComplete = false
          trailingGraphemeCluster = String.UnicodeScalarView()
          return String(scalars)
        default:
          scalars.append(contentsOf: next.unicodeScalars)
        }
      }
    }

    var string = String(scalars)

    /// We remove the last grapheme cluster because it may be modified by the next `UnicodeScalar` we receive (i.e. "fac" might be "facts" or "façade" so even if we have "fac" we only return "fa")
    if let last: String.Element = string.popLast() {
      trailingGraphemeCluster = last.unicodeScalars
    } else {
      trailingGraphemeCluster = String.UnicodeScalarView()
    }

    return string
  }

  consuming func complete() -> CharacterStream<Fragments> {
    stream
  }

  fileprivate init(stream: consuming CharacterStream<Fragments>) {
    self.stream = stream
  }

  private var isComplete: Bool = false
  private var isNextCharacterEscaped = false
  private var trailingGraphemeCluster = String.UnicodeScalarView()
  private var stream: CharacterStream<Fragments>

}

// MARK: - Stream

private struct CharacterStream<Fragments: AsyncSequence<String, Error>>: ~Copyable {

  mutating func read(
    oneOf characters: Character...,
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> Character {
    while true {
      try await fillBufferUntilNonempty()

      while let next = buffer.first {
        for character in characters {
          if next == character {
            let next = buffer.popFirst()
            assert(next == character)
            return character
          }
          throw ErrorToBeSpecialized()
        }
      }
    }
  }

  mutating func read(
    _ character: Character,
    isolation: isolated (any Actor)? = #isolation
  ) async throws {
    _ = try await read(oneOf: character)
  }

  mutating func readJSONString(
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> String {
    var fragments: [String] = []
    try await readJSONStringFragments { reader, _ in
      while let fragment = try await reader.readNextFragment() {
        fragments.append(fragment)
      }
    }
    return fragments.joined()
  }

  mutating func readJSONStringFragments<T>(
    _ body: (
      inout JSONStringFragmentReader<Fragments>,
      isolated (any Actor)?
    ) async throws -> sending T,
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> T {
    try await read("\"")
    var reader = JSONStringFragmentReader(stream: self)
    let result: T
    do {
      result = try await body(&reader, isolation)
      self = reader.complete()
    } catch {
      self = reader.complete()
      throw error
    }
    try await read("\"")
    return result
  }

  /// Does not refill the buffer if it is empty.
  mutating func readNextCharacterIfReady() -> Character? {
    buffer.popFirst()
  }

  mutating func peekString(
    count: Int,
    isolation: isolated (any Actor)? = #isolation
  ) async throws -> Substring {
    while buffer.count < 10 {
      guard let next = try await fragments.next(isolation: isolation) else {
        throw ErrorToBeSpecialized()
      }
      buffer.append(contentsOf: next)
    }
    return buffer.prefix(count)
  }

  mutating func readPeekedString(count: Int) {
    buffer.removeFirst(count)
  }

  mutating func fillBufferUntilNonempty(
    isolation: isolated (any Actor)? = #isolation
  ) async throws {
    while buffer.isEmpty {
      guard let next = try await fragments.next(isolation: isolation) else {
        throw ErrorToBeSpecialized()
      }
      buffer = next[next.startIndex...]
    }
  }

  private var buffer: Substring = ""
  private var fragments: Fragments.AsyncIterator

}

// MARK: - Errors

private struct ErrorToBeSpecialized: Error {
}
