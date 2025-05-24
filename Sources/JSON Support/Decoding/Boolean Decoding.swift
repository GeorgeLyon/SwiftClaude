// Created by Claude

extension JSON.Value {

  public mutating func decodeAsBool() throws -> Bool? {
    stream.readWhitespace()

    let candidate = try stream.peekCharacter { character in
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

    switch stream.read(candidate ? "true" : "false") {
    case .continuableMatch:
      return nil
    case .matched:
      return candidate
    case .notMatched(let error):
      throw error
    }
  }
}
