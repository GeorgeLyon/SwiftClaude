import JSONSupport

@testable public import SchemaCoding

extension SchemaCoding.Schema {

  public var schemaJSON: String {
    var stream = JSON.EncodingStream()
    stream.options = [.prettyPrint]
    var encoder = SchemaCoding.SchemaEncoder(
      stream: stream,
      descriptionPrefix: nil,
      descriptionSuffix: nil
    )
    encodeSchemaDefinition(to: &encoder)
    return encoder.stream.stringRepresentation
  }

  public func value(fromJSON json: String) -> Value {
    var stream = JSON.DecodingStream()
    stream.push(json)
    stream.finish()
    var state = initialValueDecodingState
    return try! decodeValue(from: &stream, state: &state).getValue()
  }

  public func encodedJSON(for value: Value) -> String {
    var stream = JSON.EncodingStream()
    stream.options = [.prettyPrint]
    encode(value, to: &stream)
    return stream.stringRepresentation
  }

}
