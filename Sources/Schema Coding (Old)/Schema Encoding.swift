import JSONSupport

extension SchemaCoding.Support {

  public struct Encoder: ~Copyable {
    public init() {
      stream = JSON.EncodingStream()
    }
    init(stream: consuming JSON.EncodingStream) {
      self.stream = stream
    }
    var stream: JSON.EncodingStream
  }

}
