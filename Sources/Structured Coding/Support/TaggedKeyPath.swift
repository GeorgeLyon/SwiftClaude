enum TaggedKeyPath<Root, Value>: Sendable {
  case getOnly(KeyPath<Root, Value> & Sendable)
  case writable(WritableKeyPath<Root, Value> & Sendable)
  case referenceWritable(ReferenceWritableKeyPath<Root, Value> & Sendable)

  var keyPath: KeyPath<Root, Value> & Sendable {
    switch self {
    case .getOnly(let keyPath):
      keyPath
    case .writable(let keyPath):
      keyPath
    case .referenceWritable(let keyPath):
      keyPath
    }
  }
}
