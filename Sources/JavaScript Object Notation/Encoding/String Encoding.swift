extension EncodingStream {

  public mutating func encode(_ string: String) {
    encode(utf8: string.utf8)
  }

  public mutating func encode(_ string: StaticString) {
    string.withUTF8Buffer { buffer in
      encode(utf8: buffer)
    }
  }

  /// Assumes valid UTF8
  public mutating func encode<UTF8: Collection<UInt8>>(utf8: UTF8) {
    write("\"")

    var remainder: UTF8.SubSequence = utf8[...]
    while true {
      let runEnd = remainder.firstIndex { byte in
        SpecialCharacter(byte) != nil
      }
      if let runEnd {
        write(remainder[..<runEnd])
        /// We're guaranteed that the byte at this index is a special character
        encodeSpecialCharacter(SpecialCharacter(remainder[runEnd])!)
        remainder = remainder[runEnd...].dropFirst()
      } else {
        write(remainder)
        break
      }
    }

    write("\"")
  }

  private mutating func encodeSpecialCharacter(_ c: SpecialCharacter) {
    switch c {
    case .quote:
      write("\\\"")
    case .backSlash:
      write("\\\\")
    case .backSpace:
      write("\\b")
    case .tab:
      write("\\t")
    case .newLine:
      write("\\n")
    case .formFeed:
      write("\\f")
    case .carriageReturn:
      write("\\r")
    case .controlCharacter(let high, let low):
      write("\\u00")
      write([high, low])
    }
  }

  private enum SpecialCharacter {
    case quote
    case backSlash
    case backSpace
    case tab
    case newLine
    case formFeed
    case carriageReturn
    case controlCharacter(high: UInt8, low: UInt8)

    init?(_ value: UInt8) {
      switch Byte(value: value) {
      case "\"": self = .quote
      case "\\": self = .backSlash
      case 0x08: self = .backSpace
      case 0x09: self = .tab
      case 0x0A: self = .newLine
      case 0x0C: self = .formFeed
      case 0x0D: self = .carriageReturn

      /// Control Characters
      case 0x00...0x1F:
        let high = ("0" as Byte).value + (value >> 4)
        let lowNibble = (value & 0xF)
        let low =
          if lowNibble < 10 {
            ("0" as Byte).value + lowNibble
          } else {
            ("A" as Byte).value + (lowNibble - 10)
          }
        self = .controlCharacter(high: high, low: low)

      default:
        return nil
      }
    }
  }

}
