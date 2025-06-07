import JSONSupport

extension SchemaCoding.SchemaResolver {

  public static func schema(
    representing _: String.Type = String.self
  ) -> some SchemaCoding.Schema<String> {
    StringSchema()
  }

}

extension String: SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaResolver.schema(representing: String.self)
  }

}

// MARK: - Implementation Details

private struct StringSchema: LeafSchema {

  typealias Value = String

  let type = "string"

  struct ValueDecodingState {
    var fragments: [Substring] = []
    var decodingState = JSON.StringDecodingState()
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState()
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<String> {
    let result = try stream.decodeStringFragments(
      state: &state.decodingState,
      onFragment: { state.fragments.append($0) }
    )
    switch result {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(.end):
      return .decoded(state.fragments.joined())
    }
  }

  func encode(_ value: String, to stream: inout JSON.EncodingStream) {
    stream.encode(value)
  }

}
