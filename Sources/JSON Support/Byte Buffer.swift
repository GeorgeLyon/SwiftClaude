import Collections

struct ByteBuffer: Sendable, ~Copyable {

  init() {
  }

  typealias Byte = UInt8
  typealias Bytes = Deque<Byte>

  var readableBytes: Slice<Bytes> {
    return bytes[nextReadIndex...]
  }

  mutating func didReadBytes(_ count: Int) {
    readBytesCount += count
    if readBytesRetainCount == 0 {
      droppedBytesCount += count
      bytes.removeFirst(count)
    }
  }

  mutating func append(contentsOf fragment: [Byte]) {
    bytes.append(contentsOf: fragment)
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

  mutating func reset() {
    assert(readBytesRetainCount == 0)
    readBytesCount = 0
    droppedBytesCount = 0
    bytes.removeAll(keepingCapacity: true)
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
