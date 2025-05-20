/// Namespace for JSON types
public enum JSON {

  public struct DecodingContext {

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
