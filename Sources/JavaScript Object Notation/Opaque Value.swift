public struct OpaqueValue: Sendable {

  public init(_ encode: (inout EncodingStream) throws -> Void) throws {
    var stream = EncodingStream()
    try encode(&stream)
    self.bytes = stream.bytes.array
  }

  init(bytes: [UInt8]) {
    self.bytes = bytes
  }

  let bytes: [UInt8]

}
