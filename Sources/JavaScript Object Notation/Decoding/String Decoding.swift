// MARK: - String

extension DecodingStream {

  public mutating func decodeString() async throws -> sending String {
    var bytes: [UInt8] = []
    try await decodeStringFragments { fragment in
      fragment.unvalidatedBytes.withUnsafeBytes { buffer in
        bytes.append(contentsOf: buffer)
      }
    }
    return String(copying: try UTF8Span(validating: bytes.span))
  }

  public mutating func decodeString(_ string: StaticString) async throws {
    /// This method will not correctly handle UTF8 that can be represented by multiple different byte patterns
    assert("\(string)".allSatisfy(\.isASCII))
    let start = currentPosition
    var matchedCount = 0
    try await decodeStringFragments { fragment in
      let fragmentMatchedCount = string.withUTF8Buffer { stringBytes in
        fragment.unvalidatedBytes.withUnsafeBytes { fragmentBytes in
          zip(stringBytes.dropFirst(matchedCount), fragmentBytes)
            .prefix(while: ==)
            .count
        }
      }
      guard fragmentMatchedCount >= fragment.unvalidatedBytes.count else {
        throw DecodingError.encountered(
          .expected(string),
          at: fragment.position,
          offset: fragment.isEscapeSequence ? 0 : fragmentMatchedCount
        )
      }
      assert(fragmentMatchedCount == fragment.unvalidatedBytes.count)
      matchedCount += fragmentMatchedCount
    }
    let matchedAll = string.withUTF8Buffer { $0.count == matchedCount }
    guard matchedAll else {
      throw DecodingError.encountered(.expected(string), at: start)
    }
  }

}

extension DecodingStream.StringFragment {

  public var stringValue: String {
    /// - warning: Errors are currently relative to the fragment, not the overall string
    get throws(UTF8.ValidationError) {
      String(copying: try UTF8Span(validating: unvalidatedBytes))
    }
  }

}

// MARK: - Low Level API

extension DecodingStream {

  public struct StringFragment: ~Copyable, ~Escapable {

    /// These bytes are not guaranteed to be valid UTF-8.
    /// Consumers **must** validate them before use to ensure there are not security-related issues like overlong encodings.
    public let unvalidatedBytes: Span<UInt8>

    let position: Position
    let isEscapeSequence: Bool

    @_lifetime(copy unvalidatedBytes)
    init(
      unvalidatedBytes: Span<UInt8>,
      position: consuming Position,
      isEscapeSequence: Bool
    ) {
      self.position = position
      self.unvalidatedBytes = unvalidatedBytes
      self.isEscapeSequence = isEscapeSequence
    }

  }

  /// Decodes runs of characters such that subsequent runs do not modify previous runs via things like diacritics or ZWJ
  public mutating func decodeCharacterRuns(
    _ decodeCharacterRun: (Substring) async throws -> Void
  ) async throws {
    /// The buffer holds the last character which can be modified by things like diacritics or ZWJ
    var stringBuffer = ""
    /// `unvalidatedTrailingBytes` holds scalars occurring at the end of the stream which are not valid, but may become valid as more bytes are added.
    var unvalidatedTrailingBytes: [UInt8] = []
    try await decodeStringFragments { fragment in
      /// Append the new fragment to trailing bytes
      fragment.unvalidatedBytes.withUnsafeBytes { bytes in
        unvalidatedTrailingBytes.append(contentsOf: bytes)
      }

      /// Append a maximally valid UTF8 sequence from the trailing bytes to the buffer
      do {
        do {
          let utf8 = try UTF8Span(validating: unvalidatedTrailingBytes.span)
          stringBuffer.append(String(copying: utf8))
        }
        unvalidatedTrailingBytes.removeAll(keepingCapacity: true)
      } catch let error as UTF8.ValidationError
        where error.kind == .truncatedScalar
        && error.byteOffsets.endIndex == unvalidatedTrailingBytes.endIndex
      {
        /// The last scalar is truncated
        do {
          let validBytes = unvalidatedTrailingBytes[..<error.byteOffsets.lowerBound]
          let utf8 = try UTF8Span(validating: validBytes.span)
          stringBuffer.append(String(copying: utf8))
          unvalidatedTrailingBytes.removeFirst(validBytes.count)
        } catch {
          /// The UTF8 should be valid
          assertionFailure()
          throw error
        }
      }

      if let index = stringBuffer.indices.last {
        let fragment = stringBuffer[..<index]
        try await decodeCharacterRun(fragment)
        let lastCharacter = stringBuffer[index]
        stringBuffer.removeAll(keepingCapacity: true)
        stringBuffer.append(lastCharacter)
      }
    }

    let span = try UTF8Span(validating: unvalidatedTrailingBytes.span)
    stringBuffer.append(contentsOf: String(copying: span))
    let lastFragment = stringBuffer
    try await decodeCharacterRun(Substring(lastFragment))
  }

  public mutating func decodeStringFragments(
    _ decodeFragment: (borrowing StringFragment) async throws -> Void
  ) async throws {
    func decode(
      _ bytes: Span<UInt8>,
      at position: consuming Position,
      isEscapeSequence: Bool
    ) async throws {
      try await decodeFragment(
        StringFragment(
          unvalidatedBytes: bytes,
          position: position,
          isEscapeSequence: isEscapeSequence
        )
      )
    }
    func decode(_ string: StaticString, at position: consuming Position) async throws {
      var position: Position? = position
      try await string.withUTF8Span { span in
        try await decode(span, at: position.take()!, isEscapeSequence: true)
      }
    }
    func decode(_ scalarValue: UInt32, at position: consuming Position) async throws {
      switch scalarValue {
      case 0x0000...0x007F:
        return try await decode(
          [UInt8(scalarValue)].span,
          at: position,
          isEscapeSequence: true
        )
      case 0x0080...0x07FF:
        return try await decode(
          [
            UInt8(0xC0 | ((scalarValue >> 6) & 0x1F)),
            UInt8(0x80 | (scalarValue & 0x3F)),
          ].span,
          at: position,
          isEscapeSequence: true
        )
      case 0x0800...0xFFFF:
        return try await decode(
          [
            UInt8(0xE0 | ((scalarValue >> 12) & 0x0F)),
            UInt8(0x80 | ((scalarValue >> 6) & 0x3F)),
            UInt8(0x80 | (scalarValue & 0x3F)),
          ].span,
          at: position,
          isEscapeSequence: true
        )
      default:
        return try await decode(
          [
            UInt8(0xF0 | ((scalarValue >> 18) & 0x07)),
            UInt8(0x80 | ((scalarValue >> 12) & 0x3F)),
            UInt8(0x80 | ((scalarValue >> 6) & 0x3F)),
            UInt8(0x80 | (scalarValue & 0x3F)),
          ].span,
          at: position,
          isEscapeSequence: true
        )
      }
    }

    try await readWhitespace()
    try await read("\"")

    readFragments: while true {
      try await ensureReadableByteCount(isAtLeast: 1)

      let startPosition = currentPosition
      let (fragment, specialCharacter) = try readAvailableBytes(
        until: SpecialCharacter.self,
        shouldIncrementReadCountFor: { character in
          if case .controlCharacter = character {
            return false
          } else {
            return true
          }
        }
      )
      if !fragment.isEmpty {
        try await decode(fragment.span, at: startPosition, isEscapeSequence: false)
      }
      switch specialCharacter {
      case .none:
        /// We've reached the end of the buffer and should continue reading fragments
        continue
      case .controlCharacter:
        throw DecodingError.encountered(.unescapedControlCharacter, at: currentPosition)
      case .endQuote:
        /// We've reached the end of the string
        break readFragments
      case .backSlash:
        let slashPosition = currentPosition
        /// This is an escape sequence
        enum EscapedCharacter: Byte, ByteRepresentable {
          case backspace = "b"
          case formFeed = "f"
          case doubleQuote = "\""
          case backSlash = "\\"
          case forwardSlash = "/"
          case newline = "n"
          case tab = "t"
          case carriageReturn = "r"
          case u = "u"
        }
        switch try await read(EscapedCharacter.self) {
        case .backspace: try await decode("\u{0008}", at: slashPosition)
        case .formFeed: try await decode("\u{000C}", at: slashPosition)
        case .doubleQuote: try await decode("\"", at: slashPosition)
        case .backSlash: try await decode("\\", at: slashPosition)
        case .forwardSlash: try await decode("/", at: slashPosition)
        case .newline: try await decode("\n", at: slashPosition)
        case .tab: try await decode("\t", at: slashPosition)
        case .carriageReturn: try await decode("\r", at: slashPosition)
        case .u:
          /// This is a unicode escape sequence
          let escapeSequencePosition = currentPosition
          switch try await decodeUnicodeEscapeSequence() {
          case .scalar(let value):
            try await decode(value, at: slashPosition)
          case .lowSurrogate:
            throw DecodingError.encountered(.orphanedLowSurrogate, at: escapeSequencePosition)
          case .highSurrogate(let highValue):
            try await read("\\u")
            switch try await decodeUnicodeEscapeSequence() {
            case .scalar, .highSurrogate:
              throw DecodingError.encountered(.orphanedHighSurrogate, at: escapeSequencePosition)
            case .lowSurrogate(let lowValue):
              try await decode(highValue + lowValue, at: slashPosition)
            }
          }
        }
      }
    }
  }

  private enum SpecialCharacter: ByteRepresentable {
    case backSlash
    case endQuote
    case controlCharacter(Byte)

    init?(rawValue: Byte) {
      switch rawValue {
      case "\\": self = .backSlash
      case "\"": self = .endQuote
      case "\u{0000}"..."\u{001F}": self = .controlCharacter(rawValue)
      default: return nil
      }
    }

    var rawValue: Byte {
      switch self {
      case .backSlash: "\\"
      case .endQuote: "\""
      case .controlCharacter(let byte): byte
      }
    }

    static var allCases: [DecodingStream.SpecialCharacter] {
      [.backSlash, .endQuote] + (0x00...0x1f).map(controlCharacter)
    }
  }

  private enum CodePoint {
    case scalar(UInt32)
    case lowSurrogate(UInt32)
    case highSurrogate(UInt32)
  }

  private mutating func decodeUnicodeEscapeSequence() async throws(DecodingError) -> CodePoint {
    let bytes = try await readBytes(
      whileIn: ["0"..."9", "a"..."f", "A"..."F"],
      minCount: 4,
      maxCount: 4
    )
    /// We only parse 4 hexadecimal characters so this should never fail
    let value = UInt32(bytes.stringValue, radix: 16)!
    return switch value {
    case 0xDC00...0xDFFF:
      .lowSurrogate(value - 0xDC00)
    case 0xD800...0xDBFF:
      .highSurrogate(0x10000 + ((value - 0xD800) << 10))
    default:
      .scalar(value)
    }
  }

}

// MARK: - Support

extension StaticString {
  fileprivate func withUTF8Span<E: Error, R: ~Copyable>(
    _ body: (Span<UInt8>) async throws(E) -> R
  ) async throws(E) -> R {
    if hasPointerRepresentation {
      let buffer = UnsafeBufferPointer(
        start: utf8Start,
        count: utf8CodeUnitCount
      )
      return try await body(buffer.span)
    } else {
      var storage: [4 of UInt8] = [0, 0, 0, 0]
      for (offset, byte) in unicodeScalar.utf8.enumerated() {
        storage[offset] = byte
      }
      return try await body(storage.span.extracting(0..<unicodeScalar.utf8.count))
    }
  }
}
