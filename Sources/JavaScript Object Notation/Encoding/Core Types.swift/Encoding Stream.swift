public struct EncodingStream: ~Copyable {

  // MARK: - Options

  public struct Options: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static var prettyPrint: Self { Options(rawValue: 1 << 0) }
  }

  public var options: Options = []

  // MARK: - Initialization

  public init() {

  }

  public mutating func reset() {
    bytes.reset()
    depth = 0
  }

  // MARK: - String Representation

  public var stringValue: String {
    bytes.string
  }

  // MARK: - Writing

  /// This may be removed to avoid a dependency on Unicode
  mutating func write(_ string: String) {
    self.bytes.append(string.utf8)
  }

  mutating func write(_ bytes: some Collection<UInt8>) {
    self.bytes.append(bytes)
  }

  mutating func write(_ string: StaticString) {
    string.withUTF8Buffer { buffer in
      bytes.append(buffer)
    }
  }

  // MARK: - Pretty Printing

  mutating func writeIndentation() {
    guard options.contains(.prettyPrint) else { return }
    for _ in 0..<depth {
      write("  ")
    }
  }

  mutating func writeNewline() {
    writeIfPretty("\n")
  }

  mutating func increaseNesting() {
    depth += 1
    writeIfPretty("\n")
  }

  mutating func decreaseNesting() {
    depth -= 1
    writeIfPretty("\n")
  }

  mutating func writeIfPretty(_ string: StaticString) {
    guard options.contains(.prettyPrint) else { return }
    write(string)
  }

  // MARK: - Properties

  internal private(set) var bytes: Bytes = .init()
  private var depth: Int = 0

}
