public final class Arena {

  public init(_ archetype: Archetype) {
    archetypeID = archetype.id

    /// Once an arena has been created from an archetype, we can no longer mutate the archetype
    archetype.isMutable = false

    slabs = archetype.slabs
    buffers = slabs.map { slab in
      slab.allocateAndInitializeBuffer()
    }
  }

  public func reset() {
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

  public struct Reference<Value: ~Copyable>: Sendable {
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

  struct BufferReference {
    fileprivate let index: Int
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
    isolation: isolated Actor? = #isolation,
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

}

// MARK: - Archetype

extension Arena {

  public final class Archetype {

    public init() {
      heterogenousSlab = .init(archetypeID: id, buffer: .init(index: 0))
      bitwiseCopyableSlab = .init(archetypeID: id, buffer: .init(index: 1))
      typedSlabs = []
    }

    public func addSlab<T>(
      of type: T?.Type
    ) {
      let slab = TypedSlab<T?>(
        archetypeID: id,
        buffer: .init(index: slabs.count)
      )
      assert(!typedSlabs.contains(where: { $0 is TypedSlab<T?> }))
      typedSlabs.append(slab)
    }

    public func addSlab<T: ~Copyable>(
      of type: T?.Type
    ) {
      let slab = TypedSlab<T?>(
        archetypeID: id,
        buffer: .init(index: slabs.count)
      )
      assert(!typedSlabs.contains(where: { $0 is TypedSlab<T?> }))
      typedSlabs.append(slab)
    }

    public func addSlab<T: BitwiseCopyable>(
      of type: T?.Type
    ) {
      /// Bitwise-copyable types should not need a separate slab
      assertionFailure()
    }

    public func allocate<Value: ~Copyable>(_ type: Value?.Type) -> Reference<Value?> {
      if let slab = typedSlabs.compactMap({ $0 as? TypedSlab<Value?> }).first {
        return slab.append(type)
      } else {
        return heterogenousSlab.append(type)
      }
    }

    public func allocate<Value: BitwiseCopyable>(_ type: Value?.Type) -> Reference<Value?> {
      bitwiseCopyableSlab.append(type)
    }

    fileprivate let id: Arena.Archetype.ID = .makeUnique()
    fileprivate var slabs: [Slab] {
      [heterogenousSlab, bitwiseCopyableSlab] + typedSlabs
    }
    fileprivate var isMutable: Bool = true

    private let heterogenousSlab: HeterogenousSlab
    private let bitwiseCopyableSlab: BitwiseCopyableSlab
    private var typedSlabs: [Slab] = []

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
