import Collections

// MARK: - String Fragments

extension JSON {

  struct StringFragmentReader: ~Copyable {

    mutating func readNextFragment() async throws -> String? {
      while let next = try await componentReader.readNextComponent() {
        guard !next.isEmpty else { continue }

        /// The last grapheme cluster in a string can be modified by subsequent unicode scalars.
        /// If we have the string `fac` we can't know whether the string being streamed is `facts` or `façade`.
        /// Emojis can also be modified by a `ZWJ`.
        /// To avoid confusion, we buffer the last grapheme cluster while streaming
        var fragment = trailingGraphemeCluster
        fragment.unicodeScalars.append(contentsOf: next)
        if let lastCharacter = fragment.popLast() {
          trailingGraphemeCluster = String(lastCharacter)
        } else {
          trailingGraphemeCluster = String()
        }
        return fragment
      }

      /// Reading is complete
      if trailingGraphemeCluster.isEmpty {
        return nil
      } else {
        let lastFragment = trailingGraphemeCluster
        trailingGraphemeCluster = String()
        return lastFragment
      }
    }

    init(stream: consuming ByteStream) {
      componentReader = StringComponentReader(stream: stream)
    }

    private var trailingGraphemeCluster: String = .init()
    private var componentReader: StringComponentReader

    private struct StringComponentReader: ~Copyable {
      mutating func readNextComponent() async throws -> [UnicodeScalar]? {
        guard !isComplete else {
          return nil
        }

        /// Ensure we have at least one byte in the buffer
        try await stream.ensureBytesAvailableForReading(count: 1)

        var reader = stream.reader()

        do {
          let fragment: [UnicodeScalar]?

          /// Handle escaped characters
          if isNextByteEscaped {
            let escapedScalar = try await UnicodeScalar(reader.readByte())
            switch escapedScalar {
            /// Ignored characters
            case "b", "r", "f":
              fragment = []
            /// Verbatim characters
            case "\"", "\\", "/":
              fragment = [escapedScalar]
            /// Escaped characters
            case "n":
              fragment = ["\n"]
            case "t":
              fragment = ["\t"]
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

                fragment = [scalar]

              default:
                guard let scalar = UnicodeScalar(intValue) else {
                  throw Error.invalidUnicodeScalar(intValue)
                }

                fragment = [scalar]
              }

            default:
              throw Error.invalidEscapeSequence(String(escapedScalar))
            }

            isNextByteEscaped = false
          } else {

            /// Read a string fragment
            let (readBytes, result) = try await reader.readAvailableBytes(
              until: { byte -> ControlCharacter? in
                switch UnicodeScalar(byte) {
                case "\"":
                  return .end
                case "\\":
                  return .escape
                default:
                  return nil
                }
              }
            )

            if readBytes.isEmpty {
              switch result {
              case .exhaustedReadableBytes:
                /// At the top of this function we ensure that we have at least one byte available for reading, so it should be impossible to exhaust the readable bytes and have `readBytes` be empty.
                assertionFailure()
                fragment = []
              case .stopped(let controlCaracter):
                /// We need to actually read the control character, since `readAvailableBytes` only marks the bytes before the stopCondition passes as read.
                let controlScalar = try await reader.readByte(fetchMoreDataIfNeeded: false)
                  .map(UnicodeScalar.init)
                switch controlCaracter {
                case .end:
                  assert(controlScalar == "\"")
                  isComplete = true
                  fragment = nil
                case .escape:
                  assert(controlScalar == "\\")
                  isNextByteEscaped = true
                  fragment = []
                }
              }
            } else {
              fragment = readBytes.map(UnicodeScalar.init)
            }
          }

          self = StringComponentReader(
            isComplete: isComplete,
            isNextByteEscaped: isNextByteEscaped,
            stream: reader.finish(commit: true)
          )
          return fragment
        } catch {
          self = StringComponentReader(
            isComplete: isComplete,
            isNextByteEscaped: isNextByteEscaped,
            stream: reader.finish(commit: false)
          )
          throw error
        }
      }

      fileprivate init(
        stream: consuming JSON.ByteStream
      ) {
        self.isComplete = false
        self.isNextByteEscaped = false
        self.stream = stream
      }
      private init(
        isComplete: Bool,
        isNextByteEscaped: Bool,
        stream: consuming JSON.ByteStream
      ) {
        assert(!(isComplete && isNextByteEscaped))
        self.isComplete = isComplete
        self.isNextByteEscaped = isNextByteEscaped
        self.stream = stream
      }
      private var isComplete: Bool
      private var isNextByteEscaped: Bool
      private var stream: JSON.ByteStream

      private enum ControlCharacter {
        case end
        case escape
      }
    }
  }

}

// MARK: - Data Stream

enum JSON<Fragment: Sequence & Sendable>
where
  Fragment.Element == UInt8
{

  struct ByteStream: ~Copyable, Sendable {

    struct StreamContinuationPair: ~Copyable {
      consuming func stream() -> ByteStream {
        _stream
      }
      fileprivate let _stream: ByteStream
      let continuation: Continuation
    }
    static func makeStream() -> StreamContinuationPair {
      let (fragments, continuation) = Fragments.makeStream()
      return StreamContinuationPair(
        _stream: ByteStream(fragments: fragments),
        continuation: Continuation(wrapped: continuation)
      )
    }

    struct Continuation: Sendable {

      fileprivate init(
        wrapped: Fragments.Continuation
      ) {
        self.wrapped = wrapped
      }

      func yield(_ fragment: Fragment) {
        wrapped.yield(fragment)
      }

      func finish(throwing error: Swift.Error? = nil) {
        wrapped.finish(throwing: error)
      }

      private let wrapped: Fragments.Continuation
    }

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

    private init(
      fragments: Fragments
    ) {
      self.fragments = FragmentsIterator(fragments: fragments)
    }

    /// This is the fundamental primitive for reading data from a stream
    /// Declared inside of `ByteStream` because it accesses private state
    fileprivate struct Reader: ~Copyable {

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
        let endIndex = readEndIndex + count
        if stream.buffer.endIndex < endIndex {
          if fetchMoreDataIfNeeded {
            try await stream.ensureBytesAvailableForReading(count: endIndex)
          } else {
            return nil
          }
        }
        let bytes = stream.buffer[readEndIndex..<endIndex]
        readEndIndex = endIndex
        return bytes
      }

      enum ReadAvailableBytesResult<T> {
        case exhaustedReadableBytes
        case stopped(T)
      }
      mutating func readAvailableBytes<T>(
        until stopCondition: (UInt8) throws -> T?,
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> (readBytes: Slice<Deque<UInt8>>, result: ReadAvailableBytesResult<T>) {
        while true {
          for index in stream.buffer[readEndIndex...].indices {
            if let stopResult = try stopCondition(stream.buffer[index]) {
              let readBytes = stream.buffer[readEndIndex..<index]
              readEndIndex = index
              return (readBytes, .stopped(stopResult))
            }
          }
        }
        let readBytes = stream.buffer[readEndIndex...]
        readEndIndex = stream.buffer.endIndex
        return (readBytes, .exhaustedReadableBytes)
      }

      init(stream: consuming ByteStream) {
        self.readEndIndex = stream.buffer.startIndex
        self.stream = stream
      }
      consuming func finish(commit: Bool) -> ByteStream {
        if commit {
          stream.buffer.removeSubrange(stream.buffer.startIndex..<readEndIndex)
        }
        return stream
      }

      private var readEndIndex: Buffer.Index
      private var stream: ByteStream
    }
    fileprivate consuming func reader() -> Reader {
      Reader(stream: self)
    }

    fileprivate typealias Fragments = AsyncThrowingStream<Fragment, Swift.Error>
    fileprivate typealias Buffer = Deque<UInt8>

    private var buffer: Buffer = .init()
    private var fragments: FragmentsIterator

    /// While it is usually unsafe to send an `AsyncIterator` we have a reasonable assurance that it will only ever be used serially.
    /// If `ByteStream` is sent from one isolation domain to another, we are guaranteed that it is no longer used in the original isolation domain since that would require a copy, and `ByteStream` is `~Copyable`.
    private struct FragmentsIterator: @unchecked Sendable {
      init(fragments: Fragments) {
        self.fragments = fragments.makeAsyncIterator()
      }
      mutating func next(
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> Fragment? {
        try await fragments.next(isolation: isolation)
      }
      private var fragments: Fragments.AsyncIterator
    }
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
