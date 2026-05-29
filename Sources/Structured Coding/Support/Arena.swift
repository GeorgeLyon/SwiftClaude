import BasicContainers

struct Arena: ~Escapable {

  private let storage: Storage

  @_lifetime(immortal)
  init(
    /// One page on most 64-bit systems
    slabMinimumByteCount: Int = 4096,
    slabMinimumAlignment: Int = 4096
  ) {
    self.storage = Storage(
      slabMinimumByteCount: slabMinimumByteCount,
      slabMinimumAlignment: slabMinimumAlignment
    )
  }

  @_lifetime(copy self)
  func push<Value: ~Copyable>(
    _ value: consuming Value
  ) -> ArenaRef<Value> {
    ArenaRef(
      arena: self,
      unsafePointer: storage.push(value)
    )
  }

  func withScope<T: ~Copyable, U: ~Copyable>(
    sending value: consuming sending T,
    _ body: (consuming sending T) async throws -> sending U
  ) async rethrows -> sending U {
    try await storage.withScope(sending: value, body)
  }

  func withScope<T: ~Copyable>(
    _ body: () async throws -> sending T
  ) async rethrows -> sending T {
    try await storage.withScope(sending: ()) { _ in try await body() }
  }

  /// Unsafe if `storage` is owned by another Arena
  @_lifetime(immortal)
  private init(storage: Storage) {
    self.storage = storage
  }

}

// MARK: - Arena Reference

@propertyWrapper
struct ArenaRef<Value: ~Copyable>: ~Escapable {

  var wrappedValue: Value {
    _read { yield unsafePointer.pointee }
    nonmutating _modify {
      yield &unsafePointer.pointee
    }
  }

  @_lifetime(copy arena)
  fileprivate init(
    arena: borrowing Arena,
    unsafePointer: UnsafeMutablePointer<Value>
  ) {
    self.unsafePointer = unsafePointer
  }

  let unsafePointer: UnsafeMutablePointer<Value>
}

// MARK: - Storage

private final class Storage {

  init(
    slabMinimumByteCount: Int,
    slabMinimumAlignment: Int
  ) {
    self.slabMinimumByteCount = slabMinimumByteCount
    self.slabMinimumAlignment = slabMinimumAlignment
  }

  struct Cursor {
    var slabOffset: Int
    private(set) var slabIndex: Int
    mutating func incrementSlabIndex() {
      slabIndex += 1
      slabOffset = 0
    }
  }

  func withScope<T: ~Copyable, U: ~Copyable>(
    sending value: consuming sending T,
    _ body: (consuming sending T) async throws -> sending U
  ) async rethrows -> sending U {
    let start = Cursor(slabOffset: slabOffset, slabIndex: max(slabs.count - 1, 0))
    assert(start.slabIndex >= 0)
    scopes.append(Scope())
    defer {
      let scope = scopes.removeLast()
      scope.pop(from: start, in: self)
    }
    return try await body(value)
  }

  func push<Value: ~Copyable>(_ value: consuming Value) -> UnsafeMutablePointer<Value> {
    /// All pushes require a scope
    scopes[scopes.indices.last!].push(Value.self)

    guard let index = slabs.indices.last else {
      return allocateInEmptySlab(value)
    }
    return switch slabs[index].push(value, at: &slabOffset) {
    case .success(let pointer):
      pointer
    case .failure(let value):
      allocateInEmptySlab(value)
    }
  }

  private func allocateInEmptySlab<Value: ~Copyable>(
    _ value: consuming Value
  ) -> UnsafeMutablePointer<Value> {
    var value = value
    for index in emptySlabs.indices.reversed() {
      var offset = 0
      switch emptySlabs[index].push(value, at: &offset) {
      case .success(let pointer):
        let slab = emptySlabs.remove(at: index)
        slabs.append(slab)
        slabOffset = offset
        return pointer
      case .failure(let v):
        value = v
      }
    }
    /// We don't have an empty slab that can hold this value, so we create a new one
    let slab = Slab(
      byteCount: max(MemoryLayout<Value>.size, slabMinimumByteCount),
      alignment: max(MemoryLayout<Value>.alignment, slabMinimumAlignment)
    )
    var offset = 0
    guard case .success(let pointer) = slab.push(value, at: &offset) else {
      /// This must succeed because we set the minimum size and alignment above
      fatalError()
    }
    slabs.append(slab)
    slabOffset = offset
    return pointer
  }

  private var scopes: [Scope] = []
  private var slabOffset = 0
  private var slabs: UniqueArray<Slab> = .init()
  private var emptySlabs: UniqueArray<Slab> = .init()
  private let slabMinimumByteCount: Int
  private let slabMinimumAlignment: Int

}

// MARK: - Popper

extension Storage {
  struct Scope {

    private var deinitializer: DeinitializerProtocol.Type

    init() {
      self.deinitializer = EmptyDeinitializer.self
    }

    mutating func push<Next: ~Copyable>(_ next: Next.Type) {
      deinitializer = deinitializer.appending(next)
    }

    func pop(from start: Cursor, in storage: Storage) {
      var cursor = start
      deinitializer.deinitialize(with: &cursor, in: storage)

      /// Ensure we've popped to the end
      assert(storage.slabOffset == cursor.slabOffset)
      assert(cursor.slabIndex == max(storage.slabs.count - 1, 0))

      for _ in min(start.slabIndex + 1, storage.slabs.count)..<storage.slabs.count {
        storage.emptySlabs.append(storage.slabs.removeLast())
      }
      storage.slabOffset = start.slabOffset

    }

    private protocol DeinitializerProtocol {
      static func appending<Next: ~Copyable>(_ next: Next.Type) -> DeinitializerProtocol.Type
      static func deinitialize(with cursor: inout Storage.Cursor, in storage: Storage)
    }
    private enum Deinitializer<Head: ~Copyable, Tail: DeinitializerProtocol>: DeinitializerProtocol
    {
      static func appending<Next: ~Copyable>(_ next: Next.Type) -> DeinitializerProtocol.Type {
        Deinitializer<Next, Self>.self
      }
      static func deinitialize(with cursor: inout Storage.Cursor, in storage: Storage) {
        Tail.deinitialize(with: &cursor, in: storage)
        while !storage.slabs[cursor.slabIndex].forwardPop(Head.self, at: &cursor.slabOffset) {
          cursor.incrementSlabIndex()
        }
      }
    }
    private struct EmptyDeinitializer: DeinitializerProtocol {
      static func appending<Next: ~Copyable>(_ next: Next.Type) -> DeinitializerProtocol.Type {
        Deinitializer<Next, Self>.self
      }
      static func deinitialize(with cursor: inout Storage.Cursor, in storage: Storage) {
      }
    }
  }
}

// MARK: - Slab

private struct Slab: ~Copyable {

  enum PushResult<Value: ~Copyable>: ~Copyable {
    case success(UnsafeMutablePointer<Value>)
    case failure(Value)
  }
  func push<Value: ~Copyable>(
    _ value: consuming Value,
    at offset: inout Int
  ) -> PushResult<Value> {
    guard let rawPointer = pointerToNext(Value.self, with: &offset) else {
      return .failure(value)
    }
    let pointer = rawPointer.bindMemory(to: Value.self, capacity: 1)
    pointer.initialize(to: value)
    return .success(pointer)
  }

  /// If `Value` would have fit in this slab at `offset`, pop the value and increment the offset to what it would have been after this value was pushed and return `true`.
  /// If `Value` would not have fit in this slab at `offset`, return `false`.
  /// This allows us to pop a run of values from a list of slabs FIFO with only type information and a start cursor.
  /// LIFO pop would require storing each offset as `alignedUp` is not a reversible operation.
  func forwardPop<Value: ~Copyable>(
    _ value: Value.Type,
    at offset: inout Int
  ) -> Bool {
    guard let pointer = pointerToNext(Value.self, with: &offset) else {
      return false
    }
    pointer.assumingMemoryBound(to: Value.self).deinitialize(count: 1)
    return true
  }

  init(
    byteCount: Int,
    alignment: Int
  ) {
    buffer = .allocate(byteCount: byteCount, alignment: alignment)
  }
  deinit {
    buffer.deallocate()
  }

  /// - Returns: `nil` if the value doesn't fit on this slab
  private func pointerToNext<Value: ~Copyable>(
    _ value: Value.Type = Value.self,
    with offset: inout Int
  ) -> UnsafeMutableRawPointer? {
    let candidate = (buffer.baseAddress! + offset)
      .alignedUp(for: Value.self)
    let endPointer = candidate + MemoryLayout<Value>.size
    guard endPointer <= (buffer.baseAddress! + buffer.count) else {
      return nil
    }
    offset = endPointer - buffer.baseAddress!
    return candidate
  }

  private let buffer: UnsafeMutableRawBufferPointer
}
