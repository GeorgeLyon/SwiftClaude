import Foundation
import JSONSupport

@testable import Tool

struct JSONString: ExpressibleByStringLiteral, Equatable {
  init(stringLiteral string: String) {
    /// A "best effort" minification...
    minifiedString =
      string
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
    var stream = JSON.DecodingStream()
    stream.push(json)
    stream.finish()
    var state = initialValueDecodingState
    return try! decodeValue(from: &stream, state: &state).getValue()
  }

  func encodedJSON(for value: Value) -> String {
    var stream = JSON.EncodingStream()
    encodeValue(value, to: &stream)
    let compactJSON = stream.stringRepresentation

    // Pretty print the JSON using JSONSerialization
    guard let data = compactJSON.data(using: .utf8),
      let jsonObject = try? JSONSerialization.jsonObject(with: data),
      let prettyData = try? JSONSerialization.data(
        withJSONObject: jsonObject,
        options: [.prettyPrinted, .sortedKeys]
      ),
      let prettyString = String(data: prettyData, encoding: .utf8)
    else {
      return compactJSON
    }

    return prettyString
  }

}
