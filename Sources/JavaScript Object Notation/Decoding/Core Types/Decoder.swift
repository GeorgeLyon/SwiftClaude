public actor Decoder {

  public init() {

  }

  public func decode<Value>(
    from bytes: some Collection<UInt8>,
    with operation: (inout DecodingStream) async throws -> sending Value
  ) async throws -> sending Value {
    var stream = try DecodingStream(state: state)
    state.stream(bytes)
    state.streamingComplete()
    return try await operation(&stream)
  }

  public func decode<Value, Error>(
    from bytes: some AsyncSequence<
      some Collection<UInt8> & SendableMetatype,
      Error
    > & SendableMetatype,
    with operation: (inout DecodingStream) async throws -> sending Value
  ) async throws -> sending Value {
    var stream = try DecodingStream(state: state)
    let streamingTask = Task {
      defer { state.streamingComplete() }
      for try await chunk in bytes {
        state.stream(chunk)
      }
    }
    /// `operation`'s result is `sending`, so it is disconnected by contract;
    /// the transfer wrapper only carries it through
    /// `withTaskCancellationHandler`, which does not propagate `sending`.
    let result: UnsafeTransfer<Value> = try await withTaskCancellationHandler {
      do {
        let value = try await operation(&stream)
        try await streamingTask.value
        return UnsafeTransfer(value: value)
      } catch {
        streamingTask.cancel()
        do {
          try await streamingTask.value
        } catch {
          /// Prefer the streaming error to the decoding error, if it isn't cancellation
          if !(error is CancellationError) {
            throw error
          }
        }
        throw error
      }
    } onCancel: {
      streamingTask.cancel()
    }
    return result.value
  }

  fileprivate let state = DecodingStreamState(supportsAsyncOperations: true)

}

private struct UnsafeTransfer<T>: @unchecked Sendable {
  let value: T
}
