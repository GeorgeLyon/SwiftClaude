@testable import JavaScriptObjectNotation

func encode(
  options: EncodingStream.Options = [],
  _ operation: (inout EncodingStream) throws -> Void
) rethrows -> String {
  var stream = EncodingStream()
  stream.options = options
  try operation(&stream)
  return stream.bytes.string
}
