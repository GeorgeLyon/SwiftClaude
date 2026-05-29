import JavaScriptObjectNotation

extension DecodingStream {

  mutating func withDecoder<T>(
    _ body: (inout StructuredDecoder) async throws -> sending T
  ) async rethrows -> sending T {
    var decoder = StructuredDecoder(stream: self)
    do {
      let result = try await body(&decoder)
      self = decoder.stream
      return result
    } catch {
      self = decoder.stream
      throw error
    }
  }

}
