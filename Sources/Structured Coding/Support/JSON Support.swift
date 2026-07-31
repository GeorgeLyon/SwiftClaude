import JavaScriptObjectNotation

extension DecodingStream {

  mutating func withStructuredDecodingStream<T>(
    _ body: (inout StructuredDecodingStream) async throws -> sending T
  ) async rethrows -> sending T {
    var stream = StructuredDecodingStream(json: self)
    do {
      let result = try await body(&stream)
      self = stream.json
      return result
    } catch {
      self = stream.json
      throw error
    }
  }

}
