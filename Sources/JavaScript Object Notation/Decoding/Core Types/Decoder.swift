private import DequeModule
private import Synchronization

// MARK: - Decoder

/// A JSON decoder.
///
/// A decoder owns private stream state, and access to it is serialized by
/// exclusivity rather than by an actor: every decoding entry point takes a
/// mutable reference, so overlapping decodes on one decoder are a
/// compile-time error, and a `DecodingSession` extends that exclusive access
/// for as long as it is alive. The decoder is `Sendable` — it can move freely
/// between isolation domains — precisely because exclusive access guarantees
/// its state is never touched from two domains at once.
///
/// Decoding work always executes synchronously on whatever isolation feeds
/// the decoder bytes: the caller, for `decode(from:with:)` and session
/// pushes, or `isolation`, for the asynchronous pull variant.
public struct Decoder: ~Copyable, Sendable {

  public init() {
  }

  /// Decodes a value from a complete JSON document, synchronously.
  ///
  /// `operation` must be nonisolated; see `beginDecoding(with:)`.
  public mutating func decode<Value>(
    from bytes: some Collection<UInt8>,
    with operation: @escaping (inout DecodingStream) async throws -> Value
  ) throws -> Value {
    var session = beginDecoding(with: operation)
    session.stream(bytes)
    return try session.finish()
  }

  /// Decodes a value by pulling chunks from `bytes` as they become
  /// available.
  ///
  /// Decoding work runs on `isolation` — by default the global concurrent
  /// executor, so a caller isolated to an actor (such as `MainActor`) does
  /// not parse JSON on its own executor. Pass `#isolation` to decode inline
  /// on the caller instead.
  ///
  /// `operation` must be nonisolated; see `beginDecoding(with:)`.
  public mutating func decode<Value>(
    from bytes: sending some AsyncSequence<some Collection<UInt8>, some Error>,
    isolation: isolated (any Actor)? = nil,
    with operation: @escaping (inout DecodingStream) async throws -> Value
  ) async throws -> Value {
    var session = beginDecoding(with: operation)
    do {
      for try await chunk in bytes {
        session.stream(chunk)
        if session.isDecodingComplete { break }
      }
    } catch {
      /// Unwind the in-flight decode; the byte source's error wins.
      session.streamingComplete()
      throw error
    }
    return try session.finish()
  }

  /// Begins a push-based decode.
  ///
  /// The session holds exclusive access to the decoder for its lifetime;
  /// consume it with `finish()` (or drop it) to make the decoder usable
  /// again.
  ///
  /// `operation` must be nonisolated, and may only suspend awaiting more
  /// bytes from the stream: it runs on the decoder's manually pumped
  /// executor, and an actor-isolated operation (or one awaiting an external
  /// dependency) would instead be scheduled somewhere the pump cannot run,
  /// stalling the decode — surfaced as `DecodingError.decodingStalled` when
  /// the session finishes. Beware that a closure literal formed in an
  /// actor-isolated context infers that isolation; pass a nonisolated
  /// function instead.
  @_lifetime(&self)
  public mutating func beginDecoding<Value>(
    with operation: @escaping (inout DecodingStream) async throws -> Value
  ) -> DecodingSession<Value> {
    let storage = DecodingSessionStorage<Value>(engine: engine)
    /// Sending the operation into the decode task is safe because the
    /// engine's jobs only run when pumped from within exclusive access to
    /// this decoder (directly, or via the session borrowing it), so the
    /// operation executes serially with respect to everything the caller
    /// does with it.
    let envelope = DecodingEngine.UnsafeEnvelope(session: storage, operation: operation)
    /// Detached so the decode job is enqueued on the engine immediately: a
    /// non-detached task would inherit the caller's actor context, and the
    /// job would not be pumpable until that actor ran the task body.
    Task.detached(executorPreference: engine) { [engine] in
      await engine.decode(envelope)
    }
    return DecodingSession(storage: storage)
  }

  private let engine = DecodingEngine()

}

// MARK: - Decoding Session

/// One in-flight push-based decode.
///
/// A session exclusively borrows the decoder that began it, so it cannot
/// outlive the decoder and no other decoding can start while it is alive.
/// Feed it bytes with `stream(_:)` — decoding progresses synchronously
/// within each push — and consume it with `finish()` to retrieve the value.
/// Dropping a session without finishing completes its stream, unwinding the
/// in-flight decode.
public struct DecodingSession<Value>: ~Copyable, ~Escapable {

  /// Feeds bytes to the decode, which progresses synchronously before this
  /// returns. Bytes streamed after decoding completes are ignored.
  public mutating func stream(_ bytes: some Collection<UInt8>) {
    storage.stream(bytes)
  }

  public mutating func stream(_ bytes: some Sequence<UInt8>) {
    storage.stream(bytes)
  }

  /// Marks the byte stream complete; a decode awaiting further bytes
  /// unwinds with an error. May be called multiple times.
  public mutating func streamingComplete() {
    storage.streamingComplete()
  }

  /// Whether the decode has produced a result (a value or an error).
  public var isDecodingComplete: Bool {
    storage.isDecodingComplete
  }

  /// Completes the stream and returns the decoded value, ending the
  /// session's borrow of its decoder.
  ///
  /// Throws `DecodingError.decodingStalled` if the decode produced no
  /// result even with the stream complete — which means the operation
  /// suspended on something other than the byte stream (see
  /// `Decoder.beginDecoding(with:)`).
  public consuming func finish() throws -> Value {
    storage.streamingComplete()
    guard let result = storage.result else {
      throw DecodingError.decodingStalled
    }
    return try result.get()
  }

  /// The result of the decode, if it has completed.
  var result: Result<Value, Error>? {
    storage.result
  }

  /// In-place access to the completed value, primarily for tests; public
  /// consumers retrieve the value by consuming the session via `finish()`.
  var value: Value {
    get throws {
      try storage.value
    }
  }

  @_lifetime(immortal)
  init(storage: DecodingSessionStorage<Value>) {
    self.storage = storage
  }

  let storage: DecodingSessionStorage<Value>

}

// MARK: - Session Storage

/// The reference-typed core of a `DecodingSession`: the decode task holds it
/// weakly to report its result, and its `deinit` completes the stream so an
/// abandoned session's decode unwinds instead of leaking.
final class DecodingSessionStorage<Value> {

  func stream(_ bytes: some Collection<UInt8>) {
    guard !isDecodingComplete else { return }
    engine.unsafeState.stream(bytes)
    engine.unsafeRun()
  }

  func stream(_ bytes: some Sequence<UInt8>) {
    guard !isDecodingComplete else { return }
    engine.unsafeState.stream(bytes)
    engine.unsafeRun()
  }

  func streamingComplete() {
    guard !isDecodingComplete else { return }
    engine.unsafeState.streamingComplete()
    engine.unsafeRun()
  }

  deinit {
    guard !isDecodingComplete else { return }
    engine.unsafeState.streamingComplete()
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
    /// DecodingStream's deinit, which resets the stream state, runs in the
    /// decode task. This is safe because the engine executes jobs serially.
    /// Do not continue to modify stream state once that has happened.
    result != nil
  }

  init(engine: DecodingEngine) {
    self.engine = engine
  }
  let engine: DecodingEngine
  fileprivate(set) var result: Result<Value, Error>?

}

// MARK: - Engine

/// The manually-pumped executor decoding runs on.
///
/// Decode operations are `async` (they suspend awaiting bytes), but must make
/// progress synchronously inside each push of bytes. The engine achieves this
/// by being the executor for the decode task and only ever running jobs via
/// `unsafeRun()`, which executes them inline on the pumping thread. Using an
/// actor (rather than just a task executor) guarantees all actor-isolated
/// operations happen on this executor.
final actor DecodingEngine: SerialExecutor, TaskExecutor {

  /// `nonisolated(unsafe)` because it is accessed from the pumping thread.
  /// This is safe because jobs on this executor only run via `unsafeRun()`,
  /// which is only called from within exclusive access to the owning
  /// `Decoder` (directly or via a session borrowing it), so all access is
  /// serial.
  nonisolated(unsafe) let unsafeState = DecodingStreamState()

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
        /// Overlapping live decodes are impossible — sessions exclusively
        /// borrow their decoder — but an *abandoned* session's decode may
        /// not have unwound yet; pump it to completion and try again.
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

  struct UnsafeEnvelope<Value>: @unchecked Sendable {
    weak let session: DecodingSessionStorage<Value>?
    let operation: (inout DecodingStream) async throws -> Value
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

  /// Should only be called from within exclusive access to the owning
  /// `Decoder`.
  nonisolated func unsafeRun() {
    while let job = dequeueJob() {
      job.runSynchronously(on: asUnownedSerialExecutor())
    }
  }

  private let jobs: Mutex<UniqueDeque<ExecutorJob>> = .init(.init())

}
