extension JSON {

  public struct EncodingStream: Sendable, ~Copyable {

    // MARK: - Options

    public struct Options: OptionSet, Sendable {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }

      public static let prettyPrint = Options(rawValue: 1 << 0)
    }

    public var options: Options = []

    // MARK: - Initialization

    public init() {

    }

    public mutating func reset() {
      string.unicodeScalars.removeAll(keepingCapacity: true)
      depth = 0
    }

    public var stringRepresentation: String {
      string
    }

    // MARK: - Writing

    mutating func write(_ rawString: String) {
      string.append(rawString)
    }

    mutating func write(_ rawString: Substring) {
      string.append(contentsOf: rawString)
    }

    // MARK: - Pretty Printing

    mutating func writeIfPretty(_ string: String) {
      guard options.contains(.prettyPrint) else { return }
      write(string)
    }

    mutating func writeIndentation() {
      guard options.contains(.prettyPrint) else { return }
      for _ in 0..<depth {
        write("  ")
      }
    }

    mutating func writeLineBreak(depthChange: Int = 0) {
      depth += depthChange
      writeIfPretty("\n")
    }

    // MARK: - Private Properties

    internal private(set) var string: String = ""
    private var depth: Int = 0

  }

}
