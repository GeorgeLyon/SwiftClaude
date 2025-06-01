import Foundation
import JSONSupport

@testable import Tool

struct JSONString: ExpressibleByStringLiteral, Equatable {
  init(stringLiteral string: String) {
    /// A "best effort" minification...
    minifiedString = string
      .split(separator: "\n")
      .map { $0.drop(while: \.isWhitespace) }
      .joined()
  }
  init(minifiedString: String) {
    self.minifiedString = minifiedString
  }
  let minifiedString: String
}

extension ToolInput.Schema {

  var schemaJSON: JSONString {
    var encoder = ToolInput.NewSchemaEncoder<Self>(
      stream: JSON.EncodingStream(),
      descriptionPrefix: nil,
      descriptionSuffix: nil
    )
    encodeSchemaDefinition(to: &encoder)
    return JSONString(minifiedString: encoder.stream.stringRepresentation)
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
