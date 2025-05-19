import JSONSupport

extension JSON.ByteBuffer {

  mutating func append(_ string: String) {
    append(contentsOf: Array(string.utf8))
  }

}
