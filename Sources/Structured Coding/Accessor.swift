// MARK: - Protocol

public protocol StructuredAccessor<Value>: ~Escapable {

  associatedtype Value

  /// If `true`, `mutateValue` can be called and `initializeValue` can be called more than once
  var isMutable: Bool { get }

  /// Initializes the value
  func initializeValue(to value: consuming sending Value) async throws

  /// Accesses an initialized value
  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing Value, sending Delta) async throws -> sending T
  ) async throws -> sending T

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Value, sending Delta) async throws -> sending T
  ) async throws -> sending T

}

// MARK: - Some Accessor

extension StructuredAccessor where Self: ~Escapable {

  func withSomeAccessor<T, U>(
    _ body: (borrowing SomeAccessor<Self, T>) async throws -> sending U
  ) async throws -> sending U {
    return try await body(SomeAccessor(base: self))
  }

}

struct SomeAccessor<
  Base: StructuredAccessor & ~Escapable,
  Value
>: StructuredAccessor, ~Escapable
where Base.Value == Value? {

  var isMutable: Bool { base.isMutable }

  func initializeValue(to value: consuming sending Value) async throws {
    try await base.initializeValue(to: value)
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await base.accessValue(applying: delta) { value, delta in
      guard let nonOptionalValue = value else {
        throw AccessorError.valueIsNil
      }
      return try await apply(nonOptionalValue, delta)
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await base.mutateValue(applying: delta) { value, delta in
      guard var nonOptionalValue = consume value else {
        value = .none
        throw AccessorError.valueIsNil
      }
      do {
        let result = try await apply(&nonOptionalValue, delta)
        value = nonOptionalValue
        return result
      } catch {
        value = nonOptionalValue
        throw error
      }
    }
  }

  @_lifetime(copy base)
  init(base: Base) {
    self.base = base
  }
  fileprivate let base: Base

}

// MARK: - Arena Reference

extension ArenaRef: StructuredAccessor {

  var isMutable: Bool { true }

  func initializeValue(to value: consuming sending Value) async throws {
    self.wrappedValue = value
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: (borrowing Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await apply(wrappedValue, delta)
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: (inout Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await apply(&wrappedValue, delta)
  }

}

// MARK: - Sending Accessor

func withSendingAccessor<Value>(
  of type: Value.Type = Value.self,
  in context: borrowing StructuredDecodingContext,
  _ body: (SendingAccessor<Value>) async throws -> sending Void
) async throws -> sending Value {
  try await context.withArena { arena in
    try await withSendingAccessor(in: arena, body)
  }
}

func withSendingAccessor<Value>(
  of type: Value.Type = Value.self,
  in arena: borrowing Arena,
  _ body: (SendingAccessor<Value>) async throws -> sending Void
) async throws -> sending Value {
  try await withSendingAccessor(in: arena, sending: ()) { accessor, _ in
    try await body(accessor)
  } merge: { value, _ in
    value
  }
}

func withSendingAccessor<Value, T: ~Copyable, U: ~Copyable, V: ~Copyable>(
  of type: Value.Type = Value.self,
  in context: borrowing StructuredDecodingContext,
  sending value: consuming sending T,
  to body: (SendingAccessor<Value>, consuming sending T) async throws -> sending U,
  merge: (sending Value, consuming sending U) -> sending V
) async throws -> sending V {
  try await context.withArena(sending: value) { arena, value in
    let accessor = SendingAccessor<Value>(arena: arena)
    let result = try await body(accessor, value)
    return merge(try accessor.send(), result)
  }
}

func withSendingAccessor<Value, T: ~Copyable, U: ~Copyable, V: ~Copyable>(
  of type: Value.Type = Value.self,
  in arena: borrowing Arena,
  sending value: consuming sending T,
  to body: (SendingAccessor<Value>, consuming sending T) async throws -> sending U,
  merge: (sending Value, consuming sending U) -> sending V
) async throws -> sending V {
  let accessor = SendingAccessor<Value>(arena: arena)
  let result = try await body(accessor, value)
  return merge(try accessor.send(), result)
}

struct SendingAccessor<Value>: StructuredAccessor, ~Escapable {

  var isMutable: Bool { true }

  func initializeValue(to newValue: consuming sending Value) async throws {
    self.value = newValue
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    guard let value else {
      throw AccessorError.uninitializedValue
    }
    return try await apply(value, delta)
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    guard var value else {
      throw AccessorError.uninitializedValue
    }
    defer { self.value = value }
    return try await apply(&value, delta)
  }

  fileprivate func send() throws -> sending Value {
    /// `value` is only ever accessed through `Sendable` closures with `sending` results and arguments.
    /// This ensures a non-`Sendable` `Value` cannot escape its isolation domain, and cannot have isolated non-`Sendable` values written to it.
    /// As such, it is safe to `sending` the value.
    guard let value = value.take() else {
      throw AccessorError.uninitializedValue
    }
    nonisolated(unsafe) let sentValue = value
    return sentValue
  }

  @_lifetime(copy arena)
  init(arena: borrowing Arena) {
    _value = arena.push(nil)
  }

  @ArenaRef
  private var value: Value?

}

// MARK: - Isolated Accessor

struct IsolatedAccessor<
  Base: StructuredAccessor & ~Escapable
>: StructuredAccessor, ~Escapable, Sendable {

  @_lifetime(copy base)
  init(
    isolation: isolated Actor = #isolation,
    base: Base
  ) {
    self.isolation = isolation
    self.isMutable = base.isMutable
    self.unsafeBase = base
  }

  let isMutable: Bool

  func initializeValue(to value: sending Base.Value) async throws {
    try await initializeValue(isolation: isolation, to: value)
  }

  private func initializeValue(
    isolation: isolated Actor,
    to value: sending Base.Value
  ) async throws {
    try await unsafeBase.initializeValue(to: value)
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (Base.Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await accessValue(isolation: isolation, delta: delta, apply: apply)
  }

  private func accessValue<Delta, T>(
    isolation: isolated Actor,
    delta: sending Delta,
    apply: @Sendable (Base.Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await unsafeBase.accessValue(applying: delta) { value, delta in
      try await apply(value, delta)
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Base.Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await mutateValue(isolation: isolation, delta: delta, apply: apply)
  }

  private func mutateValue<Delta, T>(
    isolation: isolated Actor,
    delta: sending Delta,
    apply: @Sendable (inout Base.Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await unsafeBase.mutateValue(applying: delta) { value, delta in
      try await apply(&value, delta)
    }
  }

  private let isolation: Actor
  private nonisolated(unsafe) var unsafeBase: Base

}

// MARK: - Errors

enum AccessorError: Error {
  case valueIsImmutable
  case valueIsNil
  case uninitializedValue
  case indexOutOfBounds
}
