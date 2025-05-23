// Created by Claude

extension JSON.DecodingStream {

  public mutating func decodeBool() throws -> Bool? {
    readWhitespace()

    let candidate = try peekCharacter { character in
      switch character {
      case "t":
        return true
      case "f":
        return false
      default:
        return nil
      }
    }
    guard let candidate else {
      return nil
    }

    switch read(candidate ? "true" : "false") {
    case .continuableMatch:
      return nil
    case .matched:
      return candidate
    case .notMatched(let error):
      throw error
    }
  }
}
