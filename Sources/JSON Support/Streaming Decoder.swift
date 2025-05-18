import Collections

public enum JSON<Fragments: AsyncSequence> where Fragments.Element == [UInt8] {

  public typealias Fragment = Fragments.Element

  public struct StreamingDecoder: Sendable, ~Copyable {

    public init() {

    }

    public mutating func reset(fragments: Fragments) {
      buffer.reset()
      self.fragmentsIterator = FragmentsIterator(fragments: fragments)
    }

    /**
     Iterates over `Fragments`.
     This type is `Sendable`, but contains a mutable instance of `Fragments.AsyncIterator`, which is _not_ `Sendable`.
     This is still safe, because `FragmentsIterator` is `~Copyable`, and does not provide API to copy the wrapped iterator out, ensuring that there is only ever one reference to the iterator.
     */
    private struct FragmentsIterator: ~Copyable, @unchecked Sendable {

      init(fragments: Fragments) {
        self.wrapped = fragments.makeAsyncIterator()
      }

      mutating func next(
        isolation: isolated (any Actor)? = #isolation
      ) async throws -> Fragment? {
        try await wrapped.next(isolation: isolation)
      }

      private var wrapped: Fragments.AsyncIterator

    }
    private var fragmentsIterator: FragmentsIterator?

    private var buffer = ByteBuffer()

  }

}

// MARK: - Reader

extension JSON {

  typealias StreamReader = StreamingDecoder.StreamReader

}

extension JSON.StreamingDecoder {

  mutating func bytesRead<T>(
    during body: (inout JSON.StreamingDecoder) async throws -> T
  ) async throws -> (readBytes: [UInt8], result: T) {
    let checkpoint = buffer.createCheckpoint()
    do {
      let result = try await body(&self)
      return (buffer.bytesRead(since: checkpoint), result)
    } catch {
      /// Ensure checkpoint is released
      _ = buffer.bytesRead(since: checkpoint)
      throw error
    }
  }

  /// Reads from the byte stream
  /// If an error is thrown the read is not committed (meaning bytes read remain in the buffer)
  mutating func read<T>(
    _ body: (inout StreamReader) async throws -> T
  ) async rethrows -> T {
    var reader = StreamReader(decoder: self)
    do {
      let result = try await body(&reader)
      self = reader.finish(commit: true)
      return result
    } catch {
      self = reader.finish(commit: false)
      throw error
    }
  }
  struct StreamReader: ~Copyable {

    typealias Bytes = ByteBuffer.Bytes

    mutating func readByte(
      isolation: isolated (any Actor)? = #isolation
    ) async throws -> UInt8 {
      try await readByte(fetchMoreDataIfNeeded: true)!
    }

    mutating func readByte(
      fetchMoreDataIfNeeded: Bool,
      isolation: isolated (any Actor)? = #isolation
    ) async throws -> UInt8? {
      try await readBytes(
        count: 1,
        fetchMoreDataIfNeeded: fetchMoreDataIfNeeded
      ) { bytes, _ in
        bytes.first!
      }
    }

    mutating func readBytes<T>(
      count: Int,
      isolation: isolated Actor? = #isolation,
      body: (borrowing Bytes.SubSequence, isolated Actor?) throws -> T
    ) async throws -> T {
      try await readBytes(count: count, fetchMoreDataIfNeeded: true, body: body)!
    }

    mutating func readBytes<T>(
      count: Int,
      fetchMoreDataIfNeeded: Bool,
      isolation: isolated Actor? = #isolation,
      body: (borrowing Bytes.SubSequence, isolated Actor?) throws -> T
    ) async throws -> T? {
      if readableBytes.count < count {
        if fetchMoreDataIfNeeded {
          try await ensureBytesAvailableForReading(count: count)
        } else {
          return nil
        }
      }
      let readBytes = readableBytes.prefix(count)
      assert(readBytes.count == count)
      readBytesCount += readBytes.count
      return try body(readBytes, isolation)
    }

    mutating func readAvailableBytes<StopResult, T>(
      until stopCondition: (UInt8) throws -> StopResult?,
      body: (Bytes.SubSequence, StopResult?) throws -> T
    ) throws -> T {
      while true {
        for index in readableBytes.indices {
          if let stopResult = try stopCondition(readableBytes[index]) {
            let readBytes = readableBytes[..<index]
            /// If we have a stop result, we consider the stopped byte read as well
            readBytesCount += readBytes.count + 1
            return try body(readBytes, stopResult)
          }
        }
      }

      /// We read all available bytes
      let readBytes = readableBytes
      readBytesCount = readBytes.count
      return try body(readBytes, nil)
    }

    mutating func ensureBytesAvailableForReading(
      count: Int,
      isolation: isolated (any Actor)? = #isolation
    ) async throws {
      while readableBytes.count < count {
        guard let next = try await decoder.fragmentsIterator?.next() else {
          throw Error.unexpectedTermination
        }
        decoder.buffer.append(contentsOf: next)
      }
    }

    fileprivate init(decoder: consuming JSON.StreamingDecoder) {
      self.decoder = decoder
    }

    fileprivate consuming func finish(commit: Bool) -> JSON.StreamingDecoder {
      if commit {
        decoder.buffer.didReadBytes(readBytesCount)
      }
      return decoder
    }

    private var readableBytes: Bytes.SubSequence {
      decoder.buffer.readableBytes.dropFirst(readBytesCount)
    }

    private var readBytesCount = 0
    private var decoder: JSON.StreamingDecoder

  }

}

// MARK: - Convenience

extension JSON.StreamingDecoder {

  mutating func read(
    _ scalar: UnicodeScalar,
    isolation: isolated (any Actor)? = #isolation
  ) async throws {
    assert(scalar.utf8.count == 1)
    try await read { reader in
      let nextByte = try await reader.readByte()
      guard nextByte == scalar.utf8[0] else {
        throw Error.unexpectedByte(nextByte)
      }
    }
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unexpectedTermination
  case unexpectedByte(UInt8)
}
