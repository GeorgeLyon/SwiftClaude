import Foundation

@testable import Tool

extension ToolInput.Schema {

  var schemaJSON: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(decoding: try! encoder.encode(self), as: UTF8.self)
  }

  func value(fromJSON json: String) -> Value {
    let decoder = JSONDecoder()
    return try! decoder.decodeValue(using: self, from: Data(json.utf8))
  }

  func encodedJSON(for value: Value) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try! encoder.encode(value, using: self)
    return String(decoding: data, as: UTF8.self)
  }

}
