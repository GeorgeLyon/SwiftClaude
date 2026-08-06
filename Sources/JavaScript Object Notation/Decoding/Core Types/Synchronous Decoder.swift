private import DequeModule
private import Synchronization

public final class SynchronousDecoder {

  public init() {
  }

  public func decode<Value>(
    from bytes: some Collection<UInt8>,
    with operation: @escaping (inout DecodingStream) async throws -> Value
  ) throws -> Value {
    let session = startDecoding(with: operation)
    privateDecoder.unsafeState.stream(bytes)
    privateDecoder.unsafeState.streamingComplete()
    privateDecoder.unsafeRun()
    guard let result = session.result else {
      throw DecodingError.decodingIncomplete
    }
    return try result.get()
  }

  func startDecoding<Value>(
    with operation: @escaping (inout DecodingStream) async throws -> Value
  ) -> DecodingSession<Value> {
    let session = DecodingSession<Value>(decoder: privateDecoder)
    /// These are safe to send into the actor since it runs on `executor` which is only ever called form this isolation domain by virtue of `DecodingSession` being non-Sendable.
    let envelope = UnsafeEnvelope(
      session: session,
      operation: operation
    )
    Task<Void, Never>(
      executorPreference: privateDecoder
    ) { [privateDecoder] in
      await privateDecoder.decode(envelope)
    }
    return session
  }

  fileprivate struct UnsafeEnvelope<Value>: @unchecked Sendable {
    weak let session: DecodingSession<Value>?
    let operation: (inout DecodingStream) async throws -> Value
  }

  /// Its possible we can get the same isolation guarantees with just a task executor, but using an actor actually guarantees all actor-isolated operations happen on the executor
  fileprivate actor PrivateDecoder: SerialExecutor, TaskExecutor {

    /// `nonisolated` to allow this to be called from `SynchronousDecoder`.
    /// This is safe because `PrivateDecoder` runs on `executor` and `executor.run()` is only called from `SynchronousDecoder` (which is non-sendable).
    nonisolated(unsafe) let unsafeState = DecodingStreamState(supportsAsyncOperations: false)

    func decode<Value>(
      _ envelope: UnsafeEnvelope<Value>
    ) async {
      /// Initialize the DecodingStream
      var decodingStream: DecodingStream
      do {
        decodingStream = try DecodingStream(state: unsafeState)
      } catch {
        do {
          guard case .concurrentDecoding = error else { throw error }
          /// Give the current task a chance to complete and try again
          unsafeRun()
          decodingStream = try DecodingStream(state: unsafeState)
        } catch {
          envelope.session?.result = .failure(error)
          return
        }
      }

      /// Perform decoding.
      let result: Result<Value, Error>
      do {
        result = .success(try await envelope.operation(&decodingStream))
      } catch {
        result = .failure(error)
      }
      envelope.session?.result = result
    }

    nonisolated var unownedExecutor: UnownedSerialExecutor {
      UnownedSerialExecutor(ordinary: self)
    }

    nonisolated func enqueue(_ job: consuming ExecutorJob) {
      var job: ExecutorJob? = consume job
      jobs.withLock { jobs in
        if let job = job.take() {
          jobs.append(job)
        }
      }
    }

    private nonisolated func dequeueJob() -> ExecutorJob? {
      jobs.withLock { jobs in
        jobs.popFirst()
      }
    }

    /// Should only be called from the owning `SynchronousDecoder`'s  isolation domain
    nonisolated func unsafeRun() {
      while let job = dequeueJob() {
        job.runSynchronously(on: asUnownedSerialExecutor())
      }
      assert(
        !unsafeState.hasStalled,
        """
        A decoding operation suspended on something other than a stream update. \
        Manually-pumped decoding cannot resume arbitrary suspensions; wrap asynchronous \
        work in `DecodingStream.performAsync` so it fails deterministically instead.
        """
      )
    }

    private let jobs: Mutex<UniqueDeque<ExecutorJob>> = .init(.init())

  }
  private let privateDecoder = PrivateDecoder()

}

// MARK: - Decoding Session

final class DecodingSession<Value> {

  func stream(_ bytes: some Collection<UInt8>) {
    guard !isDecodingComplete else { return }
    decoder.unsafeState.stream(bytes)
    decoder.unsafeRun()
  }

  func stream(_ bytes: some Sequence<UInt8>) {
    guard !isDecodingComplete else { return }
    decoder.unsafeState.stream(bytes)
    decoder.unsafeRun()
  }

  func streamingComplete() {
    guard !isDecodingComplete else { return }
    decoder.unsafeState.streamingComplete()
    decoder.unsafeRun()
  }

  deinit {
    guard !isDecodingComplete else { return }
    decoder.unsafeState.streamingComplete()
  }

  var value: Value {
    get throws {
      guard let result else {
        throw DecodingError.decodingIncomplete
      }
      return try result.get()
    }
  }

  var isDecodingComplete: Bool {
    /// DecodingStream's deinit, which resets the stream state, runs in the task.
    /// This is concurrency-safe because we execute the task serially via executor preference.
    /// Do not continue to modify stream state once that has happened.
    result != nil
  }

  fileprivate init(decoder: SynchronousDecoder.PrivateDecoder) {
    self.decoder = decoder
  }
  fileprivate let decoder: SynchronousDecoder.PrivateDecoder
  public fileprivate(set) var result: Result<Value, Error>?
}
