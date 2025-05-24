extension JSON {

  public enum ValueType {
  }

  public struct Value: ~Copyable {

    public init(decoding stream: consuming DecodingStream) {
      self.stream = stream
    }

    public var stream: DecodingStream

    public enum Kind {
      case null
      case string
      case number
      case boolean
      case object
      case array
    }

    public var kind: Kind? {
      mutating get throws {
        stream.readWhitespace()

        return try stream.peekCharacter { character -> Kind? in
          switch character {
          case "n":
            return .null
          case "\"":
            return .string
          case "0"..."9", "a"..."f", "A"..."F", "-":
            return .number
          case "t", "f":
            return .boolean
          case "{":
            return .object
          case "[":
            return .array
          default:
            return nil
          }
        }
      }
    }

  }

}
