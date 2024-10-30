/// Special key type used in schemas
public struct ToolInputSchemaKey {
  public init(_ stringValue: StaticString) {
    codingKey = CodingKey(stringValue: "\(stringValue)")
  }
  let codingKey: CodingKey
}

// MARK: - Coding

extension ToolInputSchemaKey {

  struct CodingKey: Swift.CodingKey {
    init(stringValue: String) {
      self.stringValue = stringValue
    }
    let stringValue: String

    var intValue: Int? { nil }
    init?(intValue: Int) {
      assertionFailure()
      return nil
    }
  }

}

// MARK: - Validation

extension ToolInputSchemaKey {

  /// This is formatted weird because we need this to be variadic on the arity of `keys`
  static func assertAllKeysUniqueIn<each T>(
    _ keys: @autoclosure () -> (repeat (each T, ToolInputSchemaKey))
  ) {
    assert(
      {
        var strings: Set<String> = []
        for key in repeat each keys() {
          let string = key.1.codingKey.stringValue
          guard !strings.contains(string) else { return false }
          strings.insert(string)
        }
        return true
      }()
    )
  }

}
