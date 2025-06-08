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
    var decoder = SchemaCoding.SchemaValueDecoder()
    decoder.stream.push(json)
    decoder.stream.finish()
    var state = initialValueDecodingState
    return try! decodeValue(from: &decoder, state: &state).getValue()
  }

  public func encodedJSON(for value: Value) -> String {
    var encoder = SchemaCoding.SchemaValueEncoder()
    encoder.stream.options = [.prettyPrint]
    encode(value, to: &encoder)
    return encoder.stream.stringRepresentation
  }

}
