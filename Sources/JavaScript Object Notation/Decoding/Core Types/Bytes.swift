// MARK: - Bytes

struct Bytes {

  struct SubSequence {

    static var empty: Self {
      SubSequence(storage: [])
    }

    var first: UInt8? {
      storage.first
    }

    func prefix(_ maxLength: Int) -> SubSequence {
      SubSequence(storage: storage.prefix(maxLength))
    }

    func prefix(upTo end: Int) -> SubSequence {
      SubSequence(storage: storage.prefix(upTo: end))
    }

    func prefix(whileIn acceptSet: ByteSet) -> SubSequence {
      SubSequence(storage: storage.prefix(while: acceptSet.contains(_:)))
    }

    func prefix(whileMatching string: StaticString) -> SubSequence {
      prefix(string.withUTF8Buffer { zip(storage, $0).prefix(while: ==).count })
    }

    func suffix(_ maxLength: Int) -> SubSequence {
      SubSequence(storage: storage.suffix(maxLength))
    }

    func dropFirst() -> SubSequence {
      SubSequence(storage: storage.dropFirst())
    }

    func dropFirst(_ k: Int) -> SubSequence {
      SubSequence(storage: storage.dropFirst(k))
    }

    func dropLast(_ k: Int) -> SubSequence {
      SubSequence(storage: storage.dropLast(k))
    }

    func firstIndex(where predicate: (UInt8) -> Bool) -> Int? {
      storage.firstIndex(where: predicate)
    }

    /// This should be used sparingly, as we eventually want this target to work in embedded contexts which don't have Unicode support.
    var stringValue: String {
      String(decoding: storage, as: UTF8.self)
    }

    var indices: some RandomAccessCollection<Int> {
      storage.indices
    }

    subscript(index: Int) -> UInt8 {
      storage[index]
    }

    /// This may end up being multiple spans if we move to using `Deque` for storing bytes
    var span: Span<UInt8> {
      storage.span
    }

    var array: [UInt8] {
      Array(storage)
    }

    var count: Int {
      storage.count
    }

    var isEmpty: Bool {
      storage.isEmpty
    }

    fileprivate let storage: Storage.SubSequence
  }

  var string: String {
    String(decoding: storage, as: UTF8.self)
  }

  func dropFirst(_ k: Int) -> SubSequence {
    SubSequence(storage: storage.dropFirst(k - removedByteCount))
  }

  mutating func append(
    _ bytes: some Sequence<UInt8>
  ) {
    storage.append(contentsOf: bytes)
  }

  mutating func append(
    _ bytes: some Collection<UInt8>
  ) {
    storage.append(contentsOf: bytes)
  }

  mutating func removeFirst(_ n: Int) {
    let n = n - removedByteCount
    storage.removeFirst(n)
    removedByteCount += n
  }

  mutating func reset() {
    storage.removeAll(keepingCapacity: true)
    removedByteCount = 0
  }

  /// We want to eventually move to a `Deque` but it doesn't support `Span` yet
  fileprivate typealias Storage = [UInt8]
  private var storage: Storage = []
  private var removedByteCount = 0

}

// MARK: - Byte

struct Byte: Equatable, Comparable, ExpressibleByUnicodeScalarLiteral, ExpressibleByIntegerLiteral {

  init(unicodeScalarLiteral value: StaticString) {
    self.value = value.withUTF8Buffer { buffer in
      guard buffer.count == 1 else {
        fatalError()
      }
      return buffer[0]
    }
  }

  init(integerLiteral value: UInt8) {
    self.value = value
  }

  init(value: UInt8) {
    self.value = value
  }

  static func < (lhs: Byte, rhs: Byte) -> Bool {
    lhs.value < rhs.value
  }

  let value: UInt8

}

// MARK: - Byte Representable

protocol ByteRepresentable: RawRepresentable & CaseIterable where RawValue == Byte {

}

extension ByteRepresentable {

  static var acceptSet: ByteSet {
    ByteSet(allCases.map(\.rawValue).map(ByteSet.init))
  }

}

// MARK: - Byte Set

func ... (lhs: Byte, rhs: Byte) -> ByteSet {
  .init(lhs...rhs)
}

struct ByteSet: ExpressibleByUnicodeScalarLiteral, ExpressibleByArrayLiteral {

  init(arrayLiteral elements: Self...) {
    self.init(elements)
  }

  init(_ elements: [Self]) {
    self.rangeSet = RangeSet(
      elements.map(\.rangeSet).flatMap(\.ranges)
    )
  }

  init(unicodeScalarLiteral scalar: StaticString) {
    self.init(Byte(unicodeScalarLiteral: scalar))
  }

  init(_ byte: Byte) {
    self.init(byte...byte)
  }

  init(_ range: ClosedRange<Byte>) {
    let lowerBound = UInt8(range.lowerBound.value)
    let upperBound = UInt8(range.upperBound.value) + 1
    self.rangeSet = RangeSet(lowerBound..<upperBound)
  }

  func contains(_ byte: UInt8) -> Bool {
    rangeSet.contains(byte)
  }

  func map<T>(_ transform: (Byte) -> T) -> [T] {
    rangeSet.ranges.flatMap { $0 }.map(Byte.init(value:)).map(transform)
  }

  var conditions: [DecodingError.Condition] {
    rangeSet.ranges.flatMap { range -> [DecodingError.Condition] in
      switch range.count {
      case 0:
        []
      case 1:
        [.byte(range.lowerBound)]
      case 2:
        [.byte(range.lowerBound), .byte(range.lowerBound + 1)]
      default:
        [.byteRange(range.lowerBound...(range.upperBound - 1))]
      }
    }
  }

  fileprivate init(rangeSet: RangeSet<UInt8>) {
    self.rangeSet = rangeSet
  }

  private let rangeSet: RangeSet<UInt8>

}
