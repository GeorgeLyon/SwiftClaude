import JSONSupport

@testable import Tool

extension ToolInput.Schema {

  var schemaJSON: String {
    var stream = JSON.EncodingStream()
    stream.options = [.prettyPrint]
    var encoder = ToolInput.NewSchemaEncoder<Self>(
      stream: stream,
      descriptionPrefix: nil,
      descriptionSuffix: nil
    )
    encodeSchemaDefinition(to: &encoder)
    return encoder.stream.stringRepresentation
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
    stream.options = [.prettyPrint]
    encodeValue(value, to: &stream)
    return stream.stringRepresentation
  }

}
