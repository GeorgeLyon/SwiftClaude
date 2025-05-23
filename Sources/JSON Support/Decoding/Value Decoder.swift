extension JSON {

  public enum ValueType {
    case null
    case string
    case number
    case boolean
    case object
    case array
  }

}

extension JSON.DecodingStream {

  public mutating func decodeTypeOfNextValue() throws -> JSON.ValueType? {
    readWhitespace()

    return try peekCharacter { character in
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
