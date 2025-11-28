private import BasicContainers

public final class Arena {

  func push<Value: BitwiseCopyable>(_ value: Value) -> Reference<Value> {
    Reference(
      arenaID: id,
      pointer: bitwiseCopyableSegment.push(value)
    )
  }

  func push<Value: ~Copyable>(_ value: consuming Value) -> Reference<Value> {
    let pointer: UnsafeMutablePointer<Value>
    if let segment = typedSegments[ObjectIdentifier(Value.self)] {
      if let typedSegment = segment as? TypedArenaSegment<Value> {
        pointer = typedSegment.push(value)
      } else {
        assertionFailure()
        pointer = heterogenousSegment.push(value)
      }
    } else {
      pointer = heterogenousSegment.push(value)
    }
    return Reference(
      arenaID: id,
      pointer: pointer
    )
  }

  func addTypedSegment<Value: ~Copyable>(for type: Value.Type) {
    let key = ObjectIdentifier(type)
    guard !typedSegments.keys.contains(key) else {
      assertionFailure()
      return
    }
    typedSegments[key] = TypedArenaSegment<Value>(slabCapacity: 10)
  }

  func reset() {
    id = .unique()
    heterogenousSegment.reset()
    bitwiseCopyableSegment.reset()
    for segment in typedSegments.values {
      segment.reset()
    }
  }

  private var id: Arena.ID = .unique()
  private var heterogenousSegment: HeterogenousArenaSegment = .init()
  private var bitwiseCopyableSegment: BitwiseCopyableArenaSegment = .init()
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
