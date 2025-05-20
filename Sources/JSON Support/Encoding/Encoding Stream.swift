extension JSON {

  public struct EncodingStream: Sendable, ~Copyable {

    public init() {

    }

    public mutating func reset() {
      string.unicodeScalars.removeAll(keepingCapacity: true)
    }

    mutating func write(_ rawString: String) {
      string.append(rawString)
    }

    mutating func write(_ rawString: Substring) {
      string.append(contentsOf: rawString)
    }

    internal private(set) var string: String = ""

  }

}
