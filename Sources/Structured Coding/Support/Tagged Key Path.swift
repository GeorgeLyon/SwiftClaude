enum TaggedKeyPath<Root, Value>: Sendable {

  case getOnly(KeyPath<Root, Value> & Sendable)
  case writable(WritableKeyPath<Root, Value> & Sendable)
  case referenceWritable(ReferenceWritableKeyPath<Root, Value> & Sendable)

  /// Key paths currently do not work in variadic contexts
  /// This case provides an alternate path when we need it
  case getOnlyClosure(@Sendable (Root) -> Value)

  func accessValue(on root: Root) -> Value {
    switch self {
    case .getOnlyClosure(let closure):
      closure(root)
    case .getOnly(let keyPath):
      root[keyPath: keyPath]
    case .writable(let keyPath):
      root[keyPath: keyPath]
    case .referenceWritable(let keyPath):
      root[keyPath: keyPath]
    }
  }

}
