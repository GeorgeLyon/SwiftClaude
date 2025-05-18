extension JSON.StreamingDecoder {

  mutating func readString<T>(
    _ body: (inout JSON.StringDecoder) async throws -> T
  ) async throws -> T {
    try await read("\"")

    var decoder = JSON.StringDecoder(decoder: self)
    do {
      let result = try await body(&decoder)
      try await decoder.decodeUntilComplete()
      self = decoder.finish()
      return result
    } catch {
      self = decoder.finish()
      throw error
    }
  }

}

extension JSON {

  public struct StringDecoder: ~Copyable {

    public mutating func decodeNextFragment() async throws -> String? {
      while let next = try await decoder.decodeNextComponent() {
        guard !next.isEmpty else {
          /// Empty components occur in cases like ignored escape characters
          continue
        }

        /// The last grapheme cluster in a string can be modified by subsequent unicode scalars.
        /// If we have the string `fac` we can't know whether the string being streamed is `facts` or `façade`.
        /// Emojis can also be modified by a `ZWJ`.
        /// To avoid confusion, we buffer the last grapheme cluster while streaming
        var fragment = trailingGraphemeCluster
        fragment.unicodeScalars.append(contentsOf: next)
        if !decoder.isComplete, let lastCharacter = fragment.popLast() {
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

    mutating func decodeUntilComplete() async throws {
      while (try await decodeNextFragment()) != nil { continue }
      assert(decoder.isComplete)
    }

    fileprivate init(decoder: consuming JSON.StreamingDecoder) {
      self.decoder = StringComponentDecoder(decoder: decoder)
    }

    fileprivate consuming func finish() -> JSON.StreamingDecoder {
      decoder.finish()
    }

    private var trailingGraphemeCluster: String = .init()
    private var decoder: StringComponentDecoder

  }

}

// MARK: - Implementation Details

extension JSON {

  /// What we refer to as "string components" are lower level than "string fragments".
  /// Specifically, string components are arrays of `UnicodeScalar`s which may be empty.
  fileprivate struct StringComponentDecoder: ~Copyable {

    mutating func decodeNextComponent() async throws -> [UnicodeScalar]? {
      guard !isComplete else {
        return nil
      }

      return try await decoder.read { reader in
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
            let escapeSequence = try await reader.readBytes(count: 4) { bytes, _ in
              String(String.UnicodeScalarView(bytes.map(UnicodeScalar.init)))
            }

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
              let remainingBytes = try await reader.readBytes(count: 6) { bytes, _ in
                String(String.UnicodeScalarView(bytes.map(UnicodeScalar.init)))
              }

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

          /// Only update if an error is not thrown
          isNextByteEscaped = false
        } else {
          /// Ensure we have at least one byte in the buffer
          try await reader.ensureBytesAvailableForReading(count: 1)

          /// Read a string fragment
          fragment = try reader.readAvailableBytes(
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
          ) { readBytes, controlCharacter in
            switch controlCharacter {
            case .end:
              isComplete = true
            case .escape:
              isNextByteEscaped = true
            case .none:
              break
            }
            return readBytes.map(UnicodeScalar.init)
          }

        }

        return fragment
      }
    }

    fileprivate consuming func finish() -> StreamingDecoder {
      return decoder
    }

    fileprivate init(
      decoder: consuming JSON.StreamingDecoder
    ) {
      self.isComplete = false
      self.isNextByteEscaped = false
      self.decoder = decoder
    }
    private init(
      isComplete: Bool,
      isNextByteEscaped: Bool,
      decoder: consuming JSON.StreamingDecoder
    ) {
      assert(!(isComplete && isNextByteEscaped))
      self.isComplete = isComplete
      self.isNextByteEscaped = isNextByteEscaped
      self.decoder = decoder
    }
    fileprivate private(set) var isComplete: Bool
    private var isNextByteEscaped: Bool
    private var decoder: JSON.StreamingDecoder

    private enum ControlCharacter {
      case end
      case escape
    }
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case incompleteString
  case invalidEscapeSequence(String)
  case invalidUnicodeEscapeSequence(String)
  case invalidUnicodeScalar(Int)
}
