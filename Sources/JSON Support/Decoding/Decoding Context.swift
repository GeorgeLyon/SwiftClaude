extension JSON {

  public struct DecodingContext {

    public init() {

    }

    mutating func efficientlyCollectStringFragments(
      _ body: (inout [Substring]) throws -> Void
    ) rethrows -> String {
      assert(stringFragmentsBuffer.isEmpty)
      defer { stringFragmentsBuffer.removeAll(keepingCapacity: true) }
      try body(&stringFragmentsBuffer)
      return stringFragmentsBuffer.joined()
    }
    private var stringFragmentsBuffer: [Substring] = []

  }

}
