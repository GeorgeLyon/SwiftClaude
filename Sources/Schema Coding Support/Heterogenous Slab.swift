extension Arena {

  final class HeterogenousSlab: Arena.Slab {

    init(
      archetypeID: Arena.Archetype.ID,
      buffer: Arena.BufferReference
    ) {
      self.archetypeID = archetypeID
      self.buffer = buffer
    }
    private let archetypeID: Arena.Archetype.ID
    private let buffer: Arena.BufferReference
    private var components: [Component] = []
    private var alignment: Int = MemoryLayout<Int>.alignment
    private var byteCount: Int = 0
    private var isMutable: Bool = false

    func append<Value: ~Copyable>(
      _ type: Value?.Type
    ) -> Arena.Reference<Value?> {
      guard isMutable == true else { fatalError() }
      components.append(Component(typeExistential: type))

      let componentAlignment = MemoryLayout<Value?>.alignment
      alignment = max(alignment, componentAlignment)
      let offset = (byteCount + componentAlignment - 1) & ~(componentAlignment - 1)
      byteCount = offset + MemoryLayout<Value?>.size

      return Arena.Reference(
        archetypeID: archetypeID,
        buffer: buffer,
        offset: offset
      )
    }

    func allocateAndInitializeBuffer() -> UnsafeMutableRawBufferPointer {
      isMutable = false
      let buffer =
        UnsafeMutableRawBufferPointer
        .allocate(
          byteCount: byteCount,
          alignment: alignment
        )
      forEachComponent(in: buffer) { component, pointer in
        component.initialize(pointer)
      }
      return buffer
    }

    func reset(_ buffer: UnsafeMutableRawBufferPointer) {
      guard !isMutable else { fatalError() }
      forEachComponent(in: buffer) { component, pointer in
        component.reset(pointer)
      }
    }

    func deinitializeAndDeallocate(_ buffer: UnsafeMutableRawBufferPointer) {
      guard !isMutable else { fatalError() }
      forEachComponent(in: buffer) { component, pointer in
        component.deinitialize(pointer)
      }
      buffer.deallocate()
    }

  }

}

// MARK: - Components

extension Arena.HeterogenousSlab {

  private func forEachComponent(
    in buffer: UnsafeMutableRawBufferPointer,
    _ body: (Component, UnsafeMutableRawPointer) -> Void
  ) {
    var cursor = buffer.baseAddress!
    let endPointer: UnsafeMutableRawPointer = buffer.baseAddress! + buffer.count
    for component in components {
      let pointer = component.increment(&cursor)
      assert(cursor <= endPointer)
      body(component, pointer)
    }
    assert(cursor == endPointer)
  }

  fileprivate protocol ComponentType: ~Copyable {
    static func initialValue() -> Self
  }

  fileprivate struct Component {

    let typeExistential: any (ComponentType & ~Copyable).Type

    func increment(_ cursor: inout UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
      func increment<T: ComponentType & ~Copyable>(_ type: T.Type) -> UnsafeMutableRawPointer {
        let pointer = cursor.alignedUp(for: type)
        cursor = pointer + MemoryLayout<T>.size
        return pointer
      }
      return increment(typeExistential)
    }

    func initialize(_ pointer: UnsafeMutableRawPointer) {
      func initialize<T: ComponentType & ~Copyable>(_ type: T.Type) {
        pointer
          .bindMemory(to: T.self, capacity: 1)
          .initialize(to: T.initialValue())
      }
      initialize(typeExistential)
    }

    func reset(_ pointer: UnsafeMutableRawPointer) {
      func reset<T: ComponentType & ~Copyable>(_ type: T.Type) {
        pointer
          .assumingMemoryBound(to: T.self)
          .pointee = T.initialValue()
      }
      reset(typeExistential)
    }

    func deinitialize(_ pointer: UnsafeMutableRawPointer) {
      func deinitialize<T: ComponentType & ~Copyable>(_ type: T.Type) {
        pointer
          .assumingMemoryBound(to: T.self)
          .deinitialize(count: 1)
      }
      deinitialize(typeExistential)
    }

  }

}

extension Optional: Arena.HeterogenousSlab.ComponentType where Wrapped: ~Copyable {
  fileprivate static func initialValue() -> Wrapped? { nil }
}
