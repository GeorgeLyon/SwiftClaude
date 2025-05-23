// Created by Claude

extension JSON.DecodingStream {

  public mutating func decodeNull() throws -> Bool {
    readWhitespace()

    switch read("null") {
    case .continuableMatch:
      return false
    case .matched:
      return true
    case .notMatched(let error):
      throw error
    }
  }
}
