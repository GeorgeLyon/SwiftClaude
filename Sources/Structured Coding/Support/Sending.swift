struct Sending<Value>: ~Copyable {
  init(_ value: sending Value) {
    self.value = value
  }

  mutating func apply<Delta, T>(
    _ delta: sending Delta,
    with body: @Sendable (inout Value, sending Delta) async throws -> sending T
  ) async rethrows -> sending T {
    try await body(&value, delta)
  }

  consuming func send() -> sending Value {
    value
  }

  private nonisolated(unsafe) var value: Value
}
