// Created by Claude

extension JSON.DecodingStream {

  public mutating func decodeBool() throws -> Bool? {
    readWhitespace()

    guard let firstCharacter = try peekCharacter({ $0 }) else {
      return nil
    }

    switch firstCharacter {
    case "t":
      switch read("true") {
      case .continuableMatch:
        return nil
      case .matched:
        return true
      case .notMatched(let error):
        throw error
      }

    case "f":
      switch read("false") {
      case .continuableMatch:
        return nil
      case .matched:
        return false
      case .notMatched(let error):
        throw error
      }

    default:
      return nil
    }
  }
}
