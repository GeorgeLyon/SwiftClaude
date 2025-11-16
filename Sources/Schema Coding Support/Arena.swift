public final class Arena {

  init(_ archetype: Archetype) {
    archetypeID = archetype.id

    /// Once an arena has been created from an archetype, we can no longer mutate the archetype
    archetype.isMutable = false

    slabs = archetype.slabs
    buffers = slabs.map { slab in
      slab.allocateAndInitializeBuffer()
    }
  }

  func reset() {
    for (buffer, slab) in zip(buffers, slabs) {
      slab.reset(buffer)
    }
  }

  deinit {
    for (buffer, slab) in zip(buffers, slabs) {
      slab.deinitializeAndDeallocate(buffer)
    }
  }

  private let archetypeID: Archetype.ID
  private let buffers: [UnsafeMutableRawBufferPointer]
  private let slabs: [Slab]

}

// MARK: - Reference

extension Arena {

  public struct Reference<Value: ~Copyable> {
    init(
      archetypeID: Arena.Archetype.ID,
      buffer: BufferReference,
      offset: Int
    ) {
      self.archetypeID = archetypeID
      self.buffer = buffer
      self.offset = offset
    }
    fileprivate let archetypeID: Arena.Archetype.ID
    fileprivate let buffer: BufferReference
    fileprivate let offset: Int
  }

  public subscript<Value>(reference: Reference<Value>) -> Value {
    get { withValue(reference) { $0 } }
  }

  public func withValue<Value: ~Copyable, T: ~Copyable>(
    _ reference: Reference<Value>,
    body: (inout Value) throws -> T
  ) rethrows -> T {
    try body(&pointerToValue(reference).pointee)
  }

  public func withValue<Value: ~Copyable, T: ~Copyable>(
    _ reference: Reference<Value>,
    body: (inout Value) async throws -> T
  ) async rethrows -> T {
    try await body(&pointerToValue(reference).pointee)
  }

  private func pointerToValue<Value: ~Copyable>(
    _ reference: Reference<Value>
  ) -> UnsafeMutablePointer<Value> {
    guard reference.archetypeID == archetypeID else { fatalError() }
    return buffers[reference.buffer.index]
      .baseAddress!
      .advanced(by: reference.offset)
      .assumingMemoryBound(to: Value.self)
  }

  struct BufferReference {
    fileprivate let index: Int
  }

}

// MARK: - Archetype

extension Arena {

  public final class Archetype {

    public init() {
      heterogenousSlab = .init(archetypeID: id, buffer: .init(index: 0))
      bitwiseCopyableSlap = .init(archetypeID: id, buffer: .init(index: 1))
      slabs = [heterogenousSlab, bitwiseCopyableSlap]
    }

    public func typedSlab<Component: ~Copyable>(
      _ type: Component?.Type
    ) -> TypedSlab<Component?> {
      let slab = TypedSlab<Component?>(
        archetypeID: id,
        buffer: .init(index: slabs.count)
      )
      slabs.append(slab)
      return slab
    }

    fileprivate let id: Arena.Archetype.ID = .makeUnique()
    fileprivate let heterogenousSlab: HeterogenousSlab
    fileprivate let bitwiseCopyableSlap: HeterogenousSlab
    fileprivate var slabs: [Slab] = []
    fileprivate var isMutable: Bool = true

  }

}

// MARK: - Slab

extension Arena {

  protocol Slab {
    func allocateAndInitializeBuffer() -> UnsafeMutableRawBufferPointer
    func reset(_ buffer: UnsafeMutableRawBufferPointer)
    func deinitializeAndDeallocate(_ buffer: UnsafeMutableRawBufferPointer)
  }

}
