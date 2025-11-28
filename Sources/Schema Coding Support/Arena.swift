private import BasicContainers

public final class Arena {

  public convenience init() {
    self.init(heterogenousSegmentSlabMinimumAlignment: MemoryLayout<Int>.alignment)
  }

  init(
    heterogenousSegmentSlabMinimumByteCount: Int = 4096,
    heterogenousSegmentSlabMinimumAlignment: Int = MemoryLayout<Int>.alignment,
    bitwiseCopyableSegmentSlabMinimumByteCount: Int = 4096,
    bitwiseCopyableSegmentSlabMinimumAlignment: Int = MemoryLayout<Int>.alignment,
  ) {
    heterogenousSegment = HeterogenousArenaSegment(
      slabMinimumByteCount: heterogenousSegmentSlabMinimumByteCount,
      slabMinimumAlignment: heterogenousSegmentSlabMinimumAlignment
    )
    bitwiseCopyableSegment = BitwiseCopyableArenaSegment(
      slabMinimumByteCount: bitwiseCopyableSegmentSlabMinimumByteCount,
      slabMinimumAlignment: bitwiseCopyableSegmentSlabMinimumAlignment
    )
  }

  public func push<Value: BitwiseCopyable>(_ value: Value) -> Reference<Value> {
    return Reference(
      arenaID: id,
      pointer: bitwiseCopyableSegment.push(value)
    )
  }

  public func push<Value: ~Copyable>(_ value: consuming Value) -> Reference<Value> {
    let typedSegmentKey = ObjectIdentifier(Value.self)
    let pointer: UnsafeMutablePointer<Value>
    if let segment = typedSegments[typedSegmentKey],
      let typedSegment = segment as? TypedArenaSegment<Value>
    {
      pointer = typedSegment.push(value)
    } else {
      assert(!typedSegments.keys.contains(typedSegmentKey))
      pointer = heterogenousSegment.push(value)
    }
    return Reference(
      arenaID: id,
      pointer: pointer
    )
  }

  public func addSegment<Value: ~Copyable>(
    for type: Value.Type,
    slabCapacity: Int = 10
  ) {
    let key = ObjectIdentifier(type)
    guard !typedSegments.keys.contains(key) else {
      assertionFailure()
      return
    }
    typedSegments[key] = TypedArenaSegment<Value>(slabCapacity: slabCapacity)
  }

  public func reset() {
    id = .unique()
    heterogenousSegment.reset()
    bitwiseCopyableSegment.reset()
    for segment in typedSegments.values {
      segment.reset()
    }
  }

  struct SegmentStats {
    let elementCount: Int
    let slabCount: Int
    let emptySlabCount: Int
  }
  struct TypedSegmentStats {
    subscript<Value: ~Copyable>(_ type: Value.Type) -> SegmentStats? {
      stats[ObjectIdentifier(type)]
    }
    fileprivate let stats: [ObjectIdentifier: SegmentStats]
  }
  struct Stats {
    let heterogenousSegment: SegmentStats
    let bitwiseCopyableSegment: SegmentStats
    let typedSegments: TypedSegmentStats
  }

  var stats: Stats {
    Stats(
      heterogenousSegment: heterogenousSegment.stats,
      bitwiseCopyableSegment: bitwiseCopyableSegment.stats,
      typedSegments: TypedSegmentStats(stats: typedSegments.mapValues(\.stats))
    )
  }

  private var id: Arena.ID = .unique()
  private var heterogenousSegment: HeterogenousArenaSegment
  private var bitwiseCopyableSegment: BitwiseCopyableArenaSegment
  private var typedSegments: [ObjectIdentifier: TypedArenaSegmentProtocol] = [:]

}

// MARK: - References

extension Arena {

  public subscript<Value>(reference: Reference<Value>) -> Value {
    get { withValue(reference) { $0 } }
  }

  public func withValue<Value: ~Copyable, T: ~Copyable>(
    _ reference: Reference<Value>,
    body: (inout Value) throws -> T
  ) rethrows -> T {
    try body(&reference.pointer.pointee)
  }

  public func withValue<Value: ~Copyable, T: ~Copyable>(
    _ reference: Reference<Value>,
    isolation: isolated Actor? = #isolation,
    body: (inout Value) async throws -> T
  ) async rethrows -> T {
    try await body(&reference.pointer.pointee)
  }

  public struct Reference<Value: ~Copyable> {
    fileprivate let arenaID: Arena.ID
    fileprivate let pointer: UnsafeMutablePointer<Value>
  }

}
