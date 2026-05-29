extension DecodingStream {

  public enum ValueKind: Equatable, Sendable {
    case null
    case boolean
    case number
    case string
    case array
    case object
  }

  public mutating func peekValueKind() async throws(DecodingError) -> ValueKind {
    try await readWhitespace()
    let firstCharacter = try await read(
      FirstCharacter.self,
      shouldIncrementReadCount: { _ in false }
    )
    return switch firstCharacter {
    case .null: .null
    case .boolean: .boolean
    case .number: .number
    case .string: .string
    case .array: .array
    case .object: .object
    }
  }

  public mutating func decodeValue() async throws {
    switch try await peekValueKind() {
    case .null:
      try await decodeNull()
    case .boolean:
      _ = try await decodeBoolean()
    case .number:
      _ = try await decodeNumber()
    case .string:
      try await decodeStringFragments { _ in }
    case .array:
      try await decodeArray { decoder throws in
        while !decoder.isAtEnd {
          try await decoder.decodeElement { stream throws in
            try await stream.decodeValue()
          }
        }
      }
    case .object:
      try await decodeObject { decoder in
        while !decoder.isAtEnd {
          try await decoder.decodeProperty(
            decodeName: { stream in
              try await stream.decodeStringFragments { _ in }
            },
            decodeValue: { _, stream in
              try await stream.decodeValue()
            }
          )
        }
      }
    }
  }

  private enum FirstCharacter: ByteRepresentable {
    case null
    case boolean(Byte)
    case number(Byte)
    case string
    case array
    case object

    init?(rawValue: Byte) {
      switch rawValue {
      case "n": self = .null
      case "t", "f": self = .boolean(rawValue)
      case "0"..."9", "-": self = .number(rawValue)
      case "\"": self = .string
      case "[": self = .array
      case "{": self = .object
      default: return nil
      }
    }

    var rawValue: Byte {
      switch self {
      case .null: "n"
      case .boolean(let byte): byte
      case .number(let byte): byte
      case .string: "\""
      case .array: "["
      case .object: "{"
      }
    }

    static var allCases: [DecodingStream.FirstCharacter] {
      let numberBytes: ByteSet = ["0"..."9", "-"]
      return [
        [.null, .boolean("t"), .boolean("f")],
        numberBytes.map(number),
        [.string, .array, .object],
      ].flatMap { $0 }
    }

  }

}
