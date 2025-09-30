import Synchronization

struct UniqueID<T: ~Copyable>: Hashable {
  init() {
    id = nextUniqueValue.withLock { value in
      defer { value += 1 }
      return value
    }
  }
  private let id: Int
}

private let nextUniqueValue: Mutex<Int> = .init(0)
