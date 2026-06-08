import Testing

@testable import StructuredCoding

@Suite("Variadic Tuple")
struct VariadicTupleTests {

  // MARK: - Values Round-Trip

  @Test
  func emptyTuple() {
    let tuple = VariadicTuple()
    tuple.values()
  }

  @Test
  func singleInt() {
    let tuple = VariadicTuple(42)
    let value: Int = tuple.values()
    #expect(value == 42)
  }

  @Test
  func singleString() {
    let tuple = VariadicTuple("hello")
    let value: String = tuple.values()
    #expect(value == "hello")
  }

  @Test
  func twoHomogeneousValues() {
    let tuple = VariadicTuple(1, 2)
    let (a, b) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
  }

  @Test
  func mixedTypes() {
    let tuple = VariadicTuple(42, "hello", true, 3.14)
    let (a, b, c, d) = tuple.values()
    #expect(a == 42)
    #expect(b == "hello")
    #expect(c == true)
    #expect(d == 3.14)
  }

  @Test
  func manyValues() {
    let tuple = VariadicTuple(1, 2, 3, 4, 5, 6, 7, 8)
    let (a, b, c, d, e, f, g, h) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
    #expect(c == 3)
    #expect(d == 4)
    #expect(e == 5)
    #expect(f == 6)
    #expect(g == 7)
    #expect(h == 8)
  }

  @Test
  func valuesReadableMultipleTimes() {
    let tuple = VariadicTuple(1, "two")
    for _ in 0..<10 {
      let (a, b) = tuple.values()
      #expect(a == 1)
      #expect(b == "two")
    }
  }

  // MARK: - Alignment & Layout

  @Test
  func smallElementBeforeLargeAlignment() {
    let tuple = VariadicTuple(Int8(1), Int64(2))
    let (a, b) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
  }

  /// After Int32 (offsets 0–3) and Int8 (offset 4), the Int16 must be padded
  /// forward to offset 6 — not placed at an offset overlapping earlier
  /// elements.
  @Test
  func paddingAtUnalignedCursor() {
    let tuple = VariadicTuple(Int32(1), Int8(2), Int16(3))
    let (a, b, c) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
    #expect(c == 3)
  }

  @Test
  func ascendingAlignments() {
    let tuple = VariadicTuple(Int8(1), Int16(2), Int32(3), Int64(4))
    let (a, b, c, d) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
    #expect(c == 3)
    #expect(d == 4)
  }

  @Test
  func descendingAlignments() {
    let tuple = VariadicTuple(Int64(1), Int32(2), Int16(3), Int8(4))
    let (a, b, c, d) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
    #expect(c == 3)
    #expect(d == 4)
  }

  @Test
  func packedSingleByteElements() {
    let tuple = VariadicTuple(Int8(1), Int8(2), Int8(3))
    let (a, b, c) = tuple.values()
    #expect(a == 1)
    #expect(b == 2)
    #expect(c == 3)
  }

  // MARK: - Accessors

  @Test
  func accessorReadsSingleElement() {
    let tuple = VariadicTuple(42)
    let accessor = VariadicTuple<Int>.accessors()
    #expect(tuple[accessor] == 42)
  }

  @Test
  func accessorsReadMixedElements() {
    let tuple = VariadicTuple(42, "hello", 3.14)
    let (a, b, c) = VariadicTuple<(Int, String, Double)>.accessors()
    #expect(tuple[a] == 42)
    #expect(tuple[b] == "hello")
    #expect(tuple[c] == 3.14)
  }

  @Test
  func accessorsMatchPaddedLayout() {
    let tuple = VariadicTuple(Int32(1), Int8(2), Int16(3))
    let (a, b, c) = VariadicTuple<(Int32, Int8, Int16)>.accessors()
    #expect(tuple[a] == 1)
    #expect(tuple[b] == 2)
    #expect(tuple[c] == 3)
  }

  @Test
  func copiesShareStorage() {
    let tuple = VariadicTuple(1, "two")
    let copy = tuple
    let (a, b) = VariadicTuple<(Int, String)>.accessors()
    #expect(copy[a] == 1)
    #expect(copy[b] == "two")
  }

  // MARK: - Reference Elements

  @Test
  func classElementStaysAliveWhileTupleLives() {
    let tracker = DeinitCounter()
    let tuple = VariadicTuple(DeinitProbe(tracker: tracker))
    #expect(tracker.count == 0)
    // Reading values must not over-release the stored reference.
    _ = tuple.values()
    _ = tuple.values()
    #expect(tracker.count == 0)
    withExtendedLifetime(tuple) {}
  }

  @Test
  func classElementReleasedWhenTupleDestroyed() {
    let tracker = DeinitCounter()
    do {
      let tuple = VariadicTuple(DeinitProbe(tracker: tracker))
      withExtendedLifetime(tuple) {
        #expect(tracker.count == 0)
      }
    }
    #expect(tracker.count == 1)
  }

  @Test
  func mixedElementsReleasedWhenTupleDestroyed() {
    let tracker = DeinitCounter()
    do {
      let tuple = VariadicTuple(
        DeinitProbe(tracker: tracker),
        42,
        DeinitProbe(tracker: tracker)
      )
      withExtendedLifetime(tuple) {
        #expect(tracker.count == 0)
      }
    }
    #expect(tracker.count == 2)
  }

}

// MARK: - Test Helpers

private final class DeinitCounter {
  var count = 0
}

private final class DeinitProbe {
  let tracker: DeinitCounter
  init(tracker: DeinitCounter) {
    self.tracker = tracker
  }
  deinit {
    tracker.count += 1
  }
}
