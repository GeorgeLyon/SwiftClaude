private import BasicContainers

public final class Arena {

  public init(
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
    stats.bitwiseCopyableSegmentElementCount += 1
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
      stats.typedSegmentsElementCount += 1
    } else {
      assert(!typedSegments.keys.contains(typedSegmentKey))
      pointer = heterogenousSegment.push(value)
      stats.heterogenousSegmentElementCount += 1
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
    stats = Stats()
    heterogenousSegment.reset()
    bitwiseCopyableSegment.reset()
    for segment in typedSegments.values {
      segment.reset()
    }
  }

  struct Stats {
    fileprivate(set) var heterogenousSegmentElementCount = 0
    fileprivate(set) var bitwiseCopyableSegmentElementCount = 0
    fileprivate(set) var typedSegmentsElementCount = 0
  }
  private(set) var stats = Stats()

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
