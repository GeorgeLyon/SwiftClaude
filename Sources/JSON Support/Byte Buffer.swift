import Collections

extension JSON {
  /// - warning: SubSequences returned by the reader are invalidated if the buffer is modified.
  public struct ByteBuffer: Sendable {

    public typealias Byte = UInt8

    public init() {
    }

    public mutating func reset() {
      assert(readBytesRetainCount == 0)
      readBytesCount = 0
      droppedBytesCount = 0
      bytes.removeAll(keepingCapacity: true)
    }

    public mutating func append(contentsOf fragment: [Byte]) {
      bytes.append(contentsOf: fragment)
    }

    typealias Bytes = Deque<Byte>

    var readableBytes: Slice<Bytes> {
      return bytes[nextReadIndex...]
    }

    mutating func readByte() -> Byte? {
      readBytes(count: 1)?[0]
    }

    mutating func readBytes(count: Int) -> Bytes.SubSequence? {
      let bytes = readableBytes.dropFirst(readBytesCount)
      guard bytes.count >= count else {
        return nil
      }

      readBytesCount += count
      return bytes
    }

    /// Read bytes until a condition is met
    /// If `stopCondition` returns a non-nil value, the byte it was passed is considered read but is not returned as part of `readBytes`.
    mutating func readBytes<StopResult>(
      until stopCondition: (Byte) -> StopResult?
    ) -> (readBytes: Bytes.SubSequence, stopResult: StopResult?) {
      for index in readableBytes.indices {
        if let stopResult = stopCondition(readableBytes[index]) {
          let readBytes = readableBytes[..<index]
          readBytesCount += readBytes.count + 1
          return (readBytes, stopResult)
        }
      }
      let readBytes = readableBytes
      readBytesCount += readableBytes.count
      return (readBytes, nil)
    }

    struct Checkpoint: ~Copyable {
      fileprivate let offset: Int

      consuming fileprivate func release() {
        discard self
      }

      deinit {
        assertionFailure()
      }
    }
    mutating func createCheckpoint() -> Checkpoint {
      readBytesRetainCount += 1
      return Checkpoint(offset: readBytesCount)
    }
    mutating func bytesRead(
      since checkpoint: consuming Checkpoint
    ) -> [UInt8] {
      let startIndex = bytes.index(
        bytes.startIndex,
        offsetBy: checkpoint.offset - droppedBytesCount
      )
      let readBytes = Array(bytes[startIndex..<nextReadIndex])

      checkpoint.release()
      readBytesRetainCount -= 1
      if readBytesRetainCount == 0 {
        bytes.removeFirst(readBytesCount - droppedBytesCount)
        droppedBytesCount = readBytesCount
      }

      return readBytes
    }

    private mutating func didReadBytes(_ count: Int) {
      readBytesCount += count
      if readBytesRetainCount == 0 {
        droppedBytesCount += count
        bytes.removeFirst(count)
      }
    }

    private var nextReadIndex: Bytes.Index {
      bytes.index(
        bytes.startIndex,
        offsetBy: readBytesCount - droppedBytesCount
      )
    }

    private var droppedBytesCount = 0
    private var readBytesCount = 0
    private var readBytesRetainCount = 0
    private var bytes: ByteBuffer.Bytes = Bytes()

  }

}
