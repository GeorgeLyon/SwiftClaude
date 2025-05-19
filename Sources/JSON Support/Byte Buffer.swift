import Collections

extension JSON {
  /// - warning: SubSequences returned by the reader are invalidated if the buffer is modified.
  public struct ByteBuffer: Sendable, ~Copyable {

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
      guard let bytes = readBytes(count: 1) else {
        return nil
      }
      assert(bytes.count == 1)
      return bytes.first!
    }

    mutating func readBytes(count: Int) -> Bytes.SubSequence? {
      let bytes = readableBytes
      guard bytes.count >= count else {
        return nil
      }

      readBytesCount += count
      let endIndex = bytes.index(
        bytes.startIndex,
        offsetBy: count
      )
      return bytes[..<endIndex]
    }

    mutating func readBytes(
      until stopCondition: (Byte) -> Bool
    ) -> Bytes.SubSequence {
      for index in readableBytes.indices {
        if stopCondition(readableBytes[index]) {
          let readBytes = readableBytes[..<index]
          readBytesCount += readBytes.count
          return readBytes
        }
      }
      let readBytes = readableBytes
      readBytesCount += readableBytes.count
      return readBytes
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

    mutating func restore(to checkpoint: consuming Checkpoint) {
      readBytesCount = checkpoint.offset
      release(checkpoint)
    }

    mutating func discard(_ checkpoint: consuming Checkpoint) {
      release(checkpoint)
    }

    mutating func bytesRead(
      since checkpoint: consuming Checkpoint
    ) -> [UInt8] {
      let startIndex = bytes.index(
        bytes.startIndex,
        offsetBy: checkpoint.offset - droppedBytesCount
      )
      let readBytes = Array(bytes[startIndex..<nextReadIndex])

      release(checkpoint)

      return readBytes
    }

    private mutating func release(_ checkpoint: consuming Checkpoint) {
      checkpoint.release()
      readBytesRetainCount -= 1
      if readBytesRetainCount == 0 {
        bytes.removeFirst(readBytesCount - droppedBytesCount)
        droppedBytesCount = readBytesCount
      }
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
