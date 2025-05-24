// Created by Claude

extension JSON.Value {

  public mutating func decodeAsNull() throws -> Bool {
    stream.readWhitespace()

    switch stream.read("null") {
    case .continuableMatch:
      return false
    case .matched:
      return true
    case .notMatched(let error):
      throw error
    }
  }

}
