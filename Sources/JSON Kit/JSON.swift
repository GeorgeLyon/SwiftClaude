import Collections

extension JSON {

  struct Value: ~Copyable {

    struct StringReader {
      fileprivate let stream: AsyncThrowingStream<String, Swift.Error>
    }
    consuming func read<T>(
      string: (StringReader) throws -> T
    ) async throws -> T {
      try await stream.skipWhitespace()

      let firstByte = try await stream.readByte()
      let firstScalar = UnicodeScalar(firstByte)
      switch firstScalar {
      case "\"":
        let fragments = AsyncThrowingStream<String, Swift.Error>.makeStream()
        do {
          let result = try string(StringReader(stream: fragments.stream))
          var buffer = ""
          Task {
            do {
              try await stream.readStringFragments { fragment in
                buffer.unicodeScalars.append(contentsOf: fragment)
                var string = buffer
                if let lastCharacter = string.popLast() {
                  /// Charaters may be modified by subsequent unicode code points, so we don't yield the last character until the string is complete.
                  buffer = String(lastCharacter)
                } else {
                  buffer = ""
                }
                fragments.continuation.yield(string)
              }
              if !buffer.isEmpty {
                fragments.continuation.yield(buffer)
              }
              fragments.continuation.finish()
            } catch {
              fragments.continuation.finish(throwing: error)
            }
          }
          return result
        } catch {
          fragments.continuation.finish(throwing: error)
          throw error
        }

      default:
        throw Error.unexpectedByte(firstByte)
      }

    }

    private var stream: ByteStream

  }

}

// MARK: - String Fragments

extension JSON.ByteStream {

  fileprivate mutating func readStringFragments(
    _ readStringFragment: ([UnicodeScalar]) -> Void,
    isolation: isolated (any Actor)? = #isolation
  ) async throws {
    var reader = reader()

    do {
      var isEscaped = false
      readingString: while true {

        /// Handle escaped characters
        if isEscaped {
          let escapedScalar = try await UnicodeScalar(reader.readByte())
          switch escapedScalar {
          /// Ignored characters
          case "b", "r", "f":
            break
          /// Verbatim characters
          case "\"", "\\", "/":
            readStringFragment([escapedScalar])
          /// Escaped characters
          case "n":
            readStringFragment(["\n"])
          case "t":
            readStringFragment(["\t"])
          case "u":
            let escapeSequence = String(
              String.UnicodeScalarView(
                try await reader.readBytes(count: 4)
                  .map(UnicodeScalar.init)
              )
            )

            guard
              let intValue = Int(escapeSequence, radix: 16)
            else {
              throw Error.invalidUnicodeEscapeSequence(escapeSequence)
            }

            switch intValue {

            /// Handle UTF-16 surrogate pairs
            /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
            case 0xDC00...0xDFFF:
              /// Low surrogate value without corresponding high surrogate value
              throw Error.invalidUnicodeEscapeSequence(escapeSequence)
            case 0xD800...0xDBFF:
              // This is a high surrogate pair any must be immediately followed by a low surrogate pair
              let remainingBytes = String(
                String.UnicodeScalarView(
                  try await reader.readBytes(count: 6)
                    .map(UnicodeScalar.init)
                )
              )

              guard remainingBytes.prefix(2) == "\\u" else {
                throw Error.invalidUnicodeEscapeSequence(escapeSequence + remainingBytes)
              }

              guard
                let lowIntValue = Int(remainingBytes.dropFirst(2)),
                (0xDC00...0xDFFF).contains(lowIntValue),
                let scalar = UnicodeScalar(
                  [
                    0x10000,
                    ((intValue - 0xD800) << 10),
                    lowIntValue - 0xDC00,
                  ].reduce(0, +)
                )
              else {
                throw Error.invalidUnicodeEscapeSequence(escapeSequence + remainingBytes)
              }

              readStringFragment([scalar])

            default:
              guard let scalar = UnicodeScalar(intValue) else {
                throw Error.invalidUnicodeScalar(intValue)
              }

              readStringFragment([scalar])
            }

          default:
            throw Error.invalidEscapeSequence(String(escapedScalar))
          }
          isEscaped = false
        } else if !isEscaped {
          /// Fast path for unescaped string fragments
          let readBytes = try await reader.readBytes(
            fetchMoreDataIfNeeded: false
          ) { byte in
            switch UnicodeScalar(byte) {
            case "\"", "\\":
              return true
            default:
              return false
            }
          }
          if !readBytes.isEmpty {
            readStringFragment(readBytes.map(UnicodeScalar.init))
          }

          let nextScalar = UnicodeScalar(try await reader.readByte())
          switch nextScalar {
          case "\"":
            break readingString
          case "\\":
            isEscaped = true
          default:
            readStringFragment([nextScalar])
          }
        }

      }

      self = reader.finish(commit: true)
    } catch {
      self = reader.finish(commit: false)
      throw error
    }
  }

}

// MARK: - Data Stream

enum JSON<Fragment: Sequence, Fragments: AsyncSequence<Fragment, Swift.Error>>
where Fragment.Element == UInt8 {

  struct ByteStream: ~Copyable, Sendable {

    mutating func skipWhitespace(
      isolation: isolated (any Actor)? = #isolation
    ) async throws {
      while true {
        var reader = reader()
        do {
          let nextByte = try await reader.readByte()
          if UnicodeScalar(nextByte).properties.isWhitespace {
            self = reader.finish(commit: true)
            continue
          } else {
            self = reader.finish(commit: false)
            return
          }
        } catch {
          self = reader.finish(commit: false)
          throw error
        }
      }
    }

    mutating func read(
      _ scalar: UnicodeScalar,
      isolation: isolated (any Actor)? = #isolation
    ) async throws {
      assert(scalar.utf8.count == 1)
      var reader = reader()
      do {
        let nextByte = try await reader.readByte()
        guard nextByte == scalar.utf8[0] else {
          throw Error.unexpectedByte(nextByte)
        }
        self = reader.finish(commit: true)
      } catch {
        self = reader.finish(commit: false)
        throw error
      }
    }

    mutating func readByte(
      isolation: isolated (any Actor)? = #isolation
    ) async throws -> UInt8 {
      var reader = reader()
      do {
        let nextByte = try await reader.readByte()
        self = reader.finish(commit: true)
        return nextByte
      } catch {
        self = reader.finish(commit: false)
        throw error
      }
    }

    mutating func ensureBytesAvailableForReading(
      count: Int,
      isolation: isolated (any Actor)? = #isolation
    ) async throws {
      while buffer.count < count {
        guard let next = try await fragments.next(isolation: isolation) else {
          throw Error.unexpectedTermination
        }
        buffer.append(contentsOf: next)
      }
    }

    /// This is the fundamental primitive for reading data from a stream
    /// Declared inside of `ByteStream` because it accesses private state
    private struct Reader: ~Copyable {

      mutating func readByte(
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> UInt8 {
        try await readBytes(count: 1)[0]
      }

      mutating func readByte(
        fetchMoreDataIfNeeded: Bool,
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> UInt8? {
        try await readBytes(
          count: 1,
          fetchMoreDataIfNeeded: fetchMoreDataIfNeeded
        ).map { $0[0] }
      }

      mutating func readBytes(
        count: Int,
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> Slice<Deque<UInt8>> {
        try await readBytes(count: count, fetchMoreDataIfNeeded: true)!
      }

      mutating func readBytes(
        count: Int,
        fetchMoreDataIfNeeded: Bool,
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> Slice<Deque<UInt8>>? {
        if stream.buffer.count < readByteCount + count {
          if fetchMoreDataIfNeeded {
            return nil
          } else {
            try await stream.ensureBytesAvailableForReading(count: readByteCount + count)
          }
        }
        readByteCount += count
        return stream.buffer[readByteCount..<(readByteCount + count)]
      }

      mutating func readBytes(
        fetchMoreDataIfNeeded: Bool,
        until testCondition: (UInt8) throws -> Bool,
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> Slice<Deque<UInt8>> {
        while true {
          for index in stream.buffer[readByteCount...].indices {
            if try testCondition(stream.buffer[index]) {
              readByteCount = index
              return stream.buffer[readByteCount..<index]
            }
          }

          if fetchMoreDataIfNeeded {
            try await stream.ensureBytesAvailableForReading(count: 1)
          } else {
            break
          }
        }

        readByteCount = stream.buffer.count
        return stream.buffer[readByteCount...]
      }

      init(stream: consuming ByteStream) {
        self.stream = stream
      }
      consuming func finish(commit: Bool) -> ByteStream {
        if commit {
          stream.buffer.removeFirst(readByteCount)
        }
        return stream
      }

      private var readByteCount = 0
      private var stream: ByteStream
    }
    private consuming func reader() -> Reader {
      Reader(stream: self)
    }

    private var buffer: Deque<UInt8> = .init()
    private var fragments: Fragments.AsyncIterator
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unexpectedTermination
  case unexpectedByte(UInt8)
  case invalidEscapeSequence(String)
  case invalidUnicodeEscapeSequence(String)
  case invalidUnicodeScalar(Int)
}
