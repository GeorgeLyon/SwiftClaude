private import Atomics

struct UniqueID<T: ~Copyable>: Hashable {
  init() {
    id = reserveUniqueID()
  }
  private let id: Int
}

private func reserveUniqueID() -> Int {
  while true {
    let canidate = nextUniqueValue.load(ordering: .relaxed)
    guard canidate < Int.max else {
      /// Exhausted all unique IDs
      fatalError()
    }
    let result = nextUniqueValue.weakCompareExchange(
      expected: canidate,
      desired: canidate + 1,
      ordering: .relaxed
    )
    guard result.exchanged else {
      continue
    }
    return canidate
  }
}
private let nextUniqueValue: ManagedAtomic<Int> = .init(0)
