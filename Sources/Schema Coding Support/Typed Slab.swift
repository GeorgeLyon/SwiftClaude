extension Arena {

  public final class TypedSlab<Component: ~Copyable>: Arena.Slab {

    convenience init<T>(
      archetypeID: Arena.Archetype.ID,
      buffer: Arena.BufferReference,
    ) where Component == T? {
      self.init(
        archetypeID: archetypeID,
        buffer: buffer,
        initialize: { buffer in
          buffer.initialize(repeating: nil)
        },
        reset: { buffer in
          buffer.update(repeating: nil)
        }
      )
    }

    convenience init<T: ~Copyable>(
      archetypeID: Arena.Archetype.ID,
      buffer: Arena.BufferReference,
    ) where Component == T? {
      self.init(
        archetypeID: archetypeID,
        buffer: buffer,
        initialize: { buffer in
          for index in buffer.indices {
            buffer.initializeElement(at: index, to: nil)
          }
        },
        reset: { buffer in
          for index in buffer.indices {
            buffer[index] = nil
          }
        }
      )
    }

    fileprivate init(
      archetypeID: Arena.Archetype.ID,
      buffer: Arena.BufferReference,
      initialize: @escaping @Sendable (UnsafeMutableBufferPointer<Component>) -> Void,
      reset: @escaping @Sendable (UnsafeMutableBufferPointer<Component>) -> Void
    ) {
      self.archetypeID = archetypeID
      self.buffer = buffer
      self.initialize = initialize
      self.reset = reset
    }
    private let archetypeID: Arena.Archetype.ID
    private let buffer: Arena.BufferReference
    private let initialize: @Sendable (UnsafeMutableBufferPointer<Component>) -> Void
    private let reset: @Sendable (UnsafeMutableBufferPointer<Component>) -> Void
    private var count: Int = 0
    private var isMutable: Bool = true

    func append(
      _ type: Component.Type = Component.self
    ) -> Arena.Reference<Component> {
      guard isMutable else {
        fatalError()
      }
      let reference = Arena.Reference<Component>(
        archetypeID: archetypeID,
        buffer: buffer,
        offset: MemoryLayout<Component>.stride * count
      )
      count += 1
      return reference
    }

    func allocateAndInitializeBuffer() -> UnsafeMutableRawBufferPointer {
      isMutable = false

      let buffer: UnsafeMutableBufferPointer<Component> = .allocate(capacity: count)
      initialize(buffer)
      return UnsafeMutableRawBufferPointer(buffer)
    }

    func reset(_ buffer: UnsafeMutableRawBufferPointer) {
      guard !isMutable else { fatalError() }
      let buffer =
        buffer
        .assumingMemoryBound(to: Component.self)
      reset(buffer)
    }

    func deinitializeAndDeallocate(_ buffer: UnsafeMutableRawBufferPointer) {
      let buffer =
        buffer
        .assumingMemoryBound(to: Component.self)
      buffer.deallocate()
    }

  }

}
