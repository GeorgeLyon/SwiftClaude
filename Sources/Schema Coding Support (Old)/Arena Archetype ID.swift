private import Synchronization

extension Arena.Archetype {

  struct ID: Equatable {
    static func makeUnique() -> Self {
      Self()
    }
    private init() {
      id = Self.nextUniqueValue.withLock { value in
        defer { value += 1 }
        return value
      }
    }
    private let id: Int
    private static let nextUniqueValue: Mutex<Int> = .init(0)
  }

}
