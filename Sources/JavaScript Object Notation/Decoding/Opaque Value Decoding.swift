extension DecodingStream {

  public mutating func decodeOpaqueValue() async throws -> OpaqueValue {
    try await decodeOpaqueValue { stream throws in
      try await stream.decodeValue()
    }.value
  }

  public mutating func decodeOpaqueValue<T>(
    _ decode: (inout DecodingStream) async throws -> T
  ) async rethrows -> (result: T, value: OpaqueValue) {
    let start = currentPosition
    let result = try await decode(&self)
    let value = OpaqueValue(bytes: bytesRead(since: start).array)
    return (result, value)
  }

}
