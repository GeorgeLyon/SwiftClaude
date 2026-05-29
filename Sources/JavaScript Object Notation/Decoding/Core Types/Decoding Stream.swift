// MARK: - Stream

public struct DecodingStream: ~Copyable, ~Escapable {

  public mutating func removeReadBytes() throws(DecodingError) {
    guard state.positionCount == 0 else {
      throw DecodingError.removingBytesDuringActiveRead
    }
    state.bytes.removeFirst(readByteCount)
  }

  public func readWhitespace() async throws(DecodingError) {
    _ = try await readBytes(whileIn: [" ", "\t", "\n", "\r"])
  }

  /// Reads whitespace, expecting the stream to end with no non-whitespace characters
  public func readTrailingWhitespace() async throws(DecodingError) {
    try await readWhitespace()
    guard readableBytes.isEmpty, state.isFinishedStreaming else {
      throw .encountered(.unexpectedTrailingByte, index: readByteCount)
    }
  }

  @_lifetime(&self)
  public mutating func mutate() -> DecodingStream {
    DecodingStream(mutating: &self)
  }

  @discardableResult
  func readByteIfPresent(in acceptSet: ByteSet) async throws(DecodingError) -> Bool {
    try await ensureReadableByteCount(isAtLeast: 1, allowLessIfStreamingFinished: true)
    return try await readBytes(whileIn: acceptSet, maxCount: 1).count == 1
  }

  /// Reads a single byte
  /// For convenience, the value can be transformed such that `nil` throws an error.
  func read<T: ByteRepresentable>(
    _ type: T.Type = T.self,
    shouldIncrementReadCount: (Byte) -> Bool = { _ in true }
  ) async throws(DecodingError) -> T {
    try await ensureReadableByteCount(isAtLeast: 1)
    let byte = Byte(value: readableBytes.first!)
    guard let transformed = T(rawValue: byte) else {
      throw .encountered(.expectedOneOf(T.acceptSet.conditions), at: currentPosition)
    }
    if shouldIncrementReadCount(byte) {
      state.readByteCount += 1
    }
    return transformed
  }

  func read(_ string: StaticString) async throws(DecodingError) {
    let byteCount = string.withUTF8Buffer { $0.count }
    try await ensureReadableByteCount(isAtLeast: byteCount)
    let matched = readableBytes.prefix(whileMatching: string)
    guard matched.count == byteCount else {
      assert(matched.count < byteCount)
      state.readByteCount += matched.count
      /// We would only have stopped matching if we encountered an unmatched byte
      let unmatchedByte = string.withUTF8Buffer { $0[matched.count] }
      throw .encountered(.expectedOneOf(.byte(unmatchedByte)), at: currentPosition)
    }
    state.readByteCount += byteCount
  }

  @discardableResult
  func readBytes(
    whileIn acceptSet: ByteSet,
    minCount: Int = 0,
    maxCount: Int? = nil
  ) async throws(DecodingError) -> Bytes.SubSequence {
    let start = currentPosition

    try await ensureReadableByteCount(isAtLeast: minCount)

    var remainingMaxCount = maxCount
    while (remainingMaxCount ?? .max) > 0 {
      let (readBytes, mayReadMore) = readAvailableBytes(
        whileIn: acceptSet,
        maxCount: remainingMaxCount
      )
      remainingMaxCount = remainingMaxCount.map { maxCount in
        let maxCount = maxCount - readBytes.count
        assert(maxCount >= 0)
        return maxCount
      }
      if mayReadMore {
        try await nextStreamUpdate()
      } else {
        break
      }
    }

    let bytes = bytesRead(since: start)

    guard bytes.count >= minCount else {
      throw .encountered(.expectedOneOf(acceptSet.conditions), at: currentPosition)
    }

    return bytes
  }

  /// - Parameters:
  ///   - allowLessIfStreamingFinished: If `true`, an incomplete stream will result in less readable bytes instead of throwing.
  func ensureReadableByteCount(
    isAtLeast count: Int,
    allowLessIfStreamingFinished: Bool = false
  ) async throws(DecodingError) {
    guard count > 0 else {
      return
    }
    while readableBytes.count < count {
      guard !state.isFinishedStreaming else {
        if allowLessIfStreamingFinished {
          return
        } else {
          throw .streamIncomplete
        }
      }
      try await nextStreamUpdate()
    }
  }

  func nextStreamUpdate() async throws(DecodingError) {
    /// Check for task cancellation before setting the continuation
    if Task.isCancelled {
      throw .taskCancelled
    }

    /// Wait for an update to the decoder state
    assert(state.continuation == nil)
    await withCheckedContinuation { state.continuation = $0 }

    /// Check if the continuation was resumed in response to a cancel
    if Task.isCancelled {
      throw .taskCancelled
    }
  }

  func readAvailableBytes<Terminator: ByteRepresentable>(
    until terminator: Terminator.Type,
    shouldIncrementReadCountFor: (Terminator) -> Bool = { _ in true }
  ) throws(DecodingError) -> (bytes: Bytes.SubSequence, terminator: Terminator?) {
    let acceptSet = terminator.acceptSet
    let (bytes, terminator) = readAvailableBytes(
      while: { !acceptSet.contains($0) },
      maxCount: nil
    )
    if let terminator {
      if let terminator = Terminator(rawValue: terminator) {
        if shouldIncrementReadCountFor(terminator) {
          state.readByteCount += 1
        }
        return (bytes, terminator)
      } else {
        /// Terminator accept set does not match actual behavior
        assertionFailure()
        return (bytes, nil)
      }
    } else {
      return (bytes, nil)
    }
  }

  func readAvailableBytes(
    whileIn acceptSet: ByteSet,
    maxCount: Int? = nil
  ) -> (bytes: Bytes.SubSequence, mayReadMore: Bool) {
    let (bytes, terminator) = readAvailableBytes(while: acceptSet.contains, maxCount: maxCount)

    let mayReadMore: Bool
    if state.isFinishedStreaming {
      mayReadMore = false
    } else if terminator != nil {
      mayReadMore = false
    } else if let maxCount, bytes.count >= maxCount {
      assert(bytes.count == maxCount)
      mayReadMore = false
    } else {
      mayReadMore = true
    }
    return (bytes, mayReadMore)
  }

  private func readAvailableBytes(
    while condition: (UInt8) -> Bool,
    maxCount: Int?
  ) -> (bytes: Bytes.SubSequence, terminator: Byte?) {
    let readableBytes =
      if let maxCount {
        readableBytes.prefix(maxCount)
      } else {
        readableBytes
      }
    let (readBytes, terminator): (Bytes.SubSequence, UInt8?) =
      if let end = readableBytes.firstIndex(where: { !condition($0) }) {
        (readableBytes.prefix(upTo: end), readableBytes[end])
      } else {
        (readableBytes, nil)
      }
    state.readByteCount += readBytes.count
    return (readBytes, terminator.map(Byte.init(value:)))
  }

  var readableBytes: Bytes.SubSequence {
    state.bytes.dropFirst(state.readByteCount)
  }

  var readByteCount: Int {
    state.readByteCount
  }

  struct Position: ~Copyable {
    init(
      stream: borrowing DecodingStream
    ) {
      state = stream.state
      unsafeReadByteCount = stream.readByteCount
      state.positionCount += 1
    }

    deinit {
      state.positionCount -= 1
    }

    fileprivate func readByteCount(for stream: borrowing DecodingStream) -> Int {
      assert(state === stream.state)
      return unsafeReadByteCount
    }

    private let state: DecodingStreamState
    fileprivate let unsafeReadByteCount: Int
  }

  func bytesRead(since position: borrowing Position) -> Bytes.SubSequence {
    state.bytes
      .dropFirst(position.readByteCount(for: self))
      .prefix(readByteCount - position.readByteCount(for: self))
  }

  func restore(_ position: borrowing Position) {
    state.readByteCount = position.readByteCount(for: self)
  }

  var currentPosition: Position {
    Position(stream: self)
  }

  @_lifetime(immortal)
  init(
    state: DecodingStreamState
  ) throws(DecodingError) {
    guard !state.isDecoding else {
      throw .concurrentDecoding
    }
    state.isDecoding = true
    self.isOwnerOfState = true
    self.state = state
  }

  @_lifetime(&other)
  private init(
    mutating other: inout DecodingStream
  ) {
    self.isOwnerOfState = false
    self.state = other.state
  }

  deinit {
    if isOwnerOfState {
      state.isDecoding = false
      state.reset()
    }
  }

  private let isOwnerOfState: Bool
  private let state: DecodingStreamState

}

extension DecodingError {

  static func encountered(
    _ issue: DecodingError.Issue,
    at position: borrowing DecodingStream.Position,
    offset: Int = 0
  ) -> DecodingError {
    .encountered(issue, index: position.unsafeReadByteCount + offset)
  }

}

// MARK: - State

final class DecodingStreamState {

  fileprivate func reset() {
    guard isDecoding == false, positionCount == 0 else {
      fatalError()
    }
    bytes.reset()
    isFinishedStreaming = false
    readByteCount = 0
    assert(continuation == nil)
    continuation = nil
  }

  func stream(_ chunk: some Sequence<UInt8>) {
    assert(!isFinishedStreaming)
    modifyStream {
      bytes.append(chunk)
    }
  }

  func stream(_ chunk: some Collection<UInt8>) {
    assert(!isFinishedStreaming)
    modifyStream {
      bytes.append(chunk)
    }
  }

  /// May be called multiple times
  func streamingComplete() {
    modifyStream {
      isFinishedStreaming = true
    }
  }

  private func modifyStream(_ body: () -> Void) {
    body()
    if let continuation {
      self.continuation = nil
      continuation.resume()
    }
  }

  fileprivate var bytes = Bytes()
  fileprivate var positionCount = 0
  fileprivate var isDecoding = false
  fileprivate var isFinishedStreaming = false
  fileprivate var readByteCount = 0
  fileprivate var continuation: CheckedContinuation<Void, Never>?

}
