import Testing

@testable import StructuredCoding

@Suite("Arena")
struct ArenaTests {

  // MARK: - Single Value

  @Test
  func readSingleInt() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(42)
      #expect(value.wrappedValue == 42)
    }
  }

  @Test
  func writeSingleInt() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(10)
      value.wrappedValue = 20
      #expect(value.wrappedValue == 20)
    }
  }

  @Test
  func readSingleString() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push("hello")
      #expect(value.wrappedValue == "hello")
    }
  }

  @Test
  func writeSingleString() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push("hello")
      value.wrappedValue = "world"
      #expect(value.wrappedValue == "world")
    }
  }

  @Test
  func readSingleBool() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(false)
      #expect(value.wrappedValue == false)
    }
  }

  @Test
  func readSingleDouble() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(3.14)
      #expect(value.wrappedValue == 3.14)
    }
  }

  @Test
  func writeSingleDouble() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(0.0)
      value.wrappedValue = 2.72
      #expect(value.wrappedValue == 2.72)
    }
  }

  // MARK: - Multiple Values

  @Test
  func twoValues() async {
    let arena = Arena()
    await arena.withScope {
      let a = arena.push(42)
      let b = arena.push("hello")
      #expect(a.wrappedValue == 42)
      #expect(b.wrappedValue == "hello")
    }
  }

  @Test
  func threeValues() async {
    let arena = Arena()
    await arena.withScope {
      let a = arena.push(1)
      let b = arena.push("two")
      let c = arena.push(3)
      #expect(a.wrappedValue == 1)
      #expect(b.wrappedValue == "two")
      #expect(c.wrappedValue == 3)
    }
  }

  @Test
  func fourHomogeneousValues() async {
    let arena = Arena()
    await arena.withScope {
      let a = arena.push(1)
      let b = arena.push(2)
      let c = arena.push(3)
      let d = arena.push(4)
      #expect(a.wrappedValue == 1)
      #expect(b.wrappedValue == 2)
      #expect(c.wrappedValue == 3)
      #expect(d.wrappedValue == 4)
    }
  }

  @Test
  func modifyMultipleValues() async {
    let arena = Arena()
    await arena.withScope {
      let a = arena.push(0)
      let b = arena.push("")
      a.wrappedValue = 99
      b.wrappedValue = "modified"
      #expect(a.wrappedValue == 99)
      #expect(b.wrappedValue == "modified")
    }
  }

  // MARK: - Deinitialization

  @Test
  func singleValueDeinitializedOnExit() async {
    let tracker = DeinitCounter()
    let arena = Arena()
    await arena.withScope {
      _ = arena.push(DeinitProbe(tracker: tracker))
      #expect(tracker.count == 0)
    }
    #expect(tracker.count == 1)
  }

  @Test
  func multipleValuesDeinitializedOnExit() async {
    let tracker = DeinitCounter()
    let arena = Arena()
    await arena.withScope {
      _ = arena.push(DeinitProbe(tracker: tracker))
      _ = arena.push(DeinitProbe(tracker: tracker))
      _ = arena.push(DeinitProbe(tracker: tracker))
      #expect(tracker.count == 0)
    }
    #expect(tracker.count == 3)
  }

  @Test
  func mixedTypesDeinitTracking() async {
    let tracker = DeinitCounter()
    let arena = Arena()
    await arena.withScope {
      _ = arena.push(DeinitProbe(tracker: tracker))
      let mid = arena.push(42)
      _ = arena.push(DeinitProbe(tracker: tracker))
      #expect(tracker.count == 0)
      #expect(mid.wrappedValue == 42)
    }
    #expect(tracker.count == 2)
  }

  // MARK: - Nested Scopes

  @Test
  func nestedScopeAllocatesAndCleans() async {
    let tracker = DeinitCounter()
    let arena = Arena()
    await arena.withScope {
      let outer = arena.push(1)
      #expect(outer.wrappedValue == 1)
      await arena.withScope {
        _ = arena.push(DeinitProbe(tracker: tracker))
        #expect(tracker.count == 0)
      }
      #expect(tracker.count == 1)
      #expect(outer.wrappedValue == 1)
    }
  }

  @Test
  func outerValueIntactAfterInnerScope() async {
    let arena = Arena()
    await arena.withScope {
      let outer = arena.push(42)
      await arena.withScope {
        let inner = arena.push("inner")
        #expect(inner.wrappedValue == "inner")
      }
      #expect(outer.wrappedValue == 42)
    }
  }

  @Test
  func multipleSequentialNestedScopes() async {
    let arena = Arena()
    await arena.withScope {
      let outer = arena.push(100)
      await arena.withScope {
        let inner = arena.push("first")
        #expect(inner.wrappedValue == "first")
      }
      await arena.withScope {
        let inner = arena.push("second")
        #expect(inner.wrappedValue == "second")
      }
      #expect(outer.wrappedValue == 100)
    }
  }

  @Test
  func deeplyNestedScopes() async {
    let arena = Arena()
    await arena.withScope {
      let level1 = arena.push(1)
      await arena.withScope {
        let level2 = arena.push(2)
        await arena.withScope {
          let level3 = arena.push(3)
          #expect(level3.wrappedValue == 3)
        }
        #expect(level2.wrappedValue == 2)
      }
      #expect(level1.wrappedValue == 1)
    }
  }

  @Test
  func nestedScopeDeinitOrder() async {
    let tracker = DeinitCounter()
    let arena = Arena()
    await arena.withScope {
      _ = arena.push(DeinitProbe(tracker: tracker))
      await arena.withScope {
        _ = arena.push(DeinitProbe(tracker: tracker))
        #expect(tracker.count == 0)
      }
      // Inner probe deinitialized
      #expect(tracker.count == 1)
    }
  }

  // MARK: - Empty Scopes

  /// A scope that pushes nothing onto a fresh arena must not trap when it pops.
  @Test
  func emptyScopeOnFreshArena() async {
    let arena = Arena()
    await arena.withScope {}
  }

  /// A fresh arena stays usable after an empty scope.
  @Test
  func pushAfterEmptyScope() async {
    let arena = Arena()
    await arena.withScope {}
    await arena.withScope {
      let value = arena.push(7)
      #expect(value.wrappedValue == 7)
    }
  }

  /// An empty inner scope nested in a populated outer scope is a no-op.
  @Test
  func emptyNestedScopeLeavesOuterIntact() async {
    let arena = Arena()
    await arena.withScope {
      let outer = arena.push(42)
      await arena.withScope {}
      #expect(outer.wrappedValue == 42)
    }
  }

  // MARK: - Sequential Scopes

  @Test
  func sequentialScopes() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(1)
      #expect(value.wrappedValue == 1)
    }
    await arena.withScope {
      let value = arena.push(2)
      #expect(value.wrappedValue == 2)
    }
    await arena.withScope {
      let value = arena.push(3)
      #expect(value.wrappedValue == 3)
    }
  }

  @Test
  func sequentialScopesWithDifferentTypes() async {
    let arena = Arena()
    await arena.withScope {
      let value = arena.push(42)
      #expect(value.wrappedValue == 42)
    }
    await arena.withScope {
      let value = arena.push("hello")
      #expect(value.wrappedValue == "hello")
    }
  }

  @Test
  func manySequentialScopes() async {
    let arena = Arena()
    for i in 0..<100 {
      await arena.withScope {
        let value = arena.push(i)
        #expect(value.wrappedValue == i)
      }
    }
  }

  @Test
  func sequentialScopesEachDeinitialized() async {
    let tracker = DeinitCounter()
    let arena = Arena()
    for i in 0..<5 {
      await arena.withScope {
        _ = arena.push(DeinitProbe(tracker: tracker))
        #expect(tracker.count == i)
      }
      #expect(tracker.count == i + 1)
    }
  }

  // MARK: - Slab Configuration

  @Test
  func customSmallSlabSize() async {
    let arena = Arena(
      slabMinimumByteCount: 16,
      slabMinimumAlignment: MemoryLayout<Int>.alignment
    )
    await arena.withScope {
      let value = arena.push(42)
      #expect(value.wrappedValue == 42)
    }
  }

  @Test
  func verySmallSlabForcesGrowth() async {
    let arena = Arena(
      slabMinimumByteCount: 1,
      slabMinimumAlignment: 1
    )
    await arena.withScope {
      let value = arena.push(Int64.max)
      #expect(value.wrappedValue == .max)
    }
  }

  @Test
  func defaultSlabConfiguration() async {
    let arena = Arena()
    await arena.withScope {
      let a = arena.push(42)
      let b = arena.push("hello")
      let c = arena.push(99)
      #expect(a.wrappedValue == 42)
      #expect(b.wrappedValue == "hello")
      #expect(c.wrappedValue == 99)
    }
  }

  // MARK: - Slab Boundaries

  // The tests in this section configure a 32-byte / 8-byte-aligned slab so
  // allocation boundaries land deterministically: each `Int64` (or class
  // reference) is exactly one quarter of a slab, so the fifth such push
  // always forces growth.

  /// A scope whose live allocations exceed the initial slab must force a
  /// second (and further) slab rather than trapping.
  @Test
  func growsBeyondFirstSlab() async {
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      // 20 × Int64 spans five slabs (four pushes per 32-byte slab).
      for i in 0..<20 {
        let ref = arena.push(Int64(i))
        #expect(ref.wrappedValue == Int64(i))
      }
    }
  }

  /// References returned for allocations on slab N must stay valid after
  /// slab N+1 is allocated and used: each slab owns its own heap buffer,
  /// so adding a new slab must not invalidate pointers into the old one.
  @Test
  func refsAcrossSlabBoundaryStayValid() async {
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      let a = arena.push(Int64(10))
      let b = arena.push(Int64(20))
      let c = arena.push(Int64(30))
      let d = arena.push(Int64(40))  // slab 1 now full (4 × 8B)
      let e = arena.push(Int64(50))  // forces slab 2
      let f = arena.push(Int64(60))
      a.wrappedValue = 100  // mutate on either side of the boundary
      f.wrappedValue = 600
      #expect(a.wrappedValue == 100)
      #expect(b.wrappedValue == 20)
      #expect(c.wrappedValue == 30)
      #expect(d.wrappedValue == 40)
      #expect(e.wrappedValue == 50)
      #expect(f.wrappedValue == 600)
    }
  }

  /// Heterogeneous types with different alignments allocate correctly
  /// across a slab boundary.
  @Test
  func mixedAlignmentsAcrossSlabBoundary() async {
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      let a = arena.push(Int8(1))    // offset 0  → 1
      let b = arena.push(Int64(2))   // aligned to 8: offset 8 → 16
      let c = arena.push(Int8(3))    // offset 16 → 17
      let d = arena.push(Int64(4))   // aligned to 8: offset 24 → 32 (full)
      let e = arena.push(Int8(5))    // new slab, offset 0
      let f = arena.push(Int64(6))   // aligned to 8: offset 8
      #expect(a.wrappedValue == 1)
      #expect(b.wrappedValue == 2)
      #expect(c.wrappedValue == 3)
      #expect(d.wrappedValue == 4)
      #expect(e.wrappedValue == 5)
      #expect(f.wrappedValue == 6)
    }
  }

  /// A single push of a value larger than the configured minimum must
  /// allocate a bespoke slab sized to fit it.
  @Test
  func valueLargerThanSlabMinimumAllocatesBespokeSlab() async {
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      // 6 × Int64 = 48 bytes, larger than the 32-byte minimum.
      let big = arena.push((Int64(1), Int64(2), Int64(3), Int64(4), Int64(5), Int64(6)))
      let (a, b, c, d, e, f) = big.wrappedValue
      #expect(a == 1)
      #expect(b == 2)
      #expect(c == 3)
      #expect(d == 4)
      #expect(e == 5)
      #expect(f == 6)
    }
  }

  /// All values pushed across a slab boundary must be deinitialized on
  /// scope exit, even though the deinit chain has to walk from one slab
  /// into the next.
  @Test
  func deinitAcrossSlabBoundaryDeinitializesEverything() async {
    let tracker = DeinitCounter()
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      // Class references are 8 bytes → 4 fit per slab; 6 pushes force a
      // boundary mid-run.
      _ = arena.push(DeinitProbe(tracker: tracker))
      _ = arena.push(DeinitProbe(tracker: tracker))
      _ = arena.push(DeinitProbe(tracker: tracker))
      _ = arena.push(DeinitProbe(tracker: tracker))
      _ = arena.push(DeinitProbe(tracker: tracker))  // forces new slab
      _ = arena.push(DeinitProbe(tracker: tracker))
      #expect(tracker.count == 0)
    }
    #expect(tracker.count == 6)
  }

  /// Deinit walks values in allocation (FIFO) order, including when the
  /// run of values crosses a slab boundary.
  @Test
  func deinitOrderIsAllocationOrderAcrossSlabs() async {
    let tracker = DeinitOrderTracker()
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      _ = arena.push(OrderedDeinitProbe(id: 1, tracker: tracker))
      _ = arena.push(OrderedDeinitProbe(id: 2, tracker: tracker))
      _ = arena.push(OrderedDeinitProbe(id: 3, tracker: tracker))
      _ = arena.push(OrderedDeinitProbe(id: 4, tracker: tracker))
      _ = arena.push(OrderedDeinitProbe(id: 5, tracker: tracker))  // new slab
      _ = arena.push(OrderedDeinitProbe(id: 6, tracker: tracker))
    }
    #expect(tracker.order == [1, 2, 3, 4, 5, 6])
  }

  /// An inner scope that grows the arena to a new slab pops back to exactly
  /// the outer cursor on exit, letting the outer scope keep allocating into
  /// the slab it was using before the nested scope.
  @Test
  func nestedScopeGrowsAndPopsBackToOuter() async {
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      let outerA = arena.push(Int64(1))
      let outerB = arena.push(Int64(2))
      await arena.withScope {
        let inner1 = arena.push(Int64(10))
        let inner2 = arena.push(Int64(20))  // slab 1 now full
        let inner3 = arena.push(Int64(30))  // forces slab 2
        let inner4 = arena.push(Int64(40))
        #expect(inner1.wrappedValue == 10)
        #expect(inner2.wrappedValue == 20)
        #expect(inner3.wrappedValue == 30)
        #expect(inner4.wrappedValue == 40)
      }
      #expect(outerA.wrappedValue == 1)
      #expect(outerB.wrappedValue == 2)
      // Outer can still push into the (now half-full) original slab.
      let outerC = arena.push(Int64(3))
      let outerD = arena.push(Int64(4))
      #expect(outerC.wrappedValue == 3)
      #expect(outerD.wrappedValue == 4)
    }
  }

  /// Sequential scopes reuse slabs popped into the empty-slab pool: the
  /// second scope can grow past one slab without leaving the arena in an
  /// inconsistent state.
  @Test
  func sequentialScopesReuseEmptiedSlabs() async {
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await arena.withScope {
      for i in 0..<8 {  // 2 slabs' worth
        let ref = arena.push(Int64(i))
        #expect(ref.wrappedValue == Int64(i))
      }
    }
    await arena.withScope {
      for i in 0..<8 {
        let ref = arena.push(Int64(100 + i))
        #expect(ref.wrappedValue == Int64(100 + i))
      }
    }
  }

  /// A scope whose body throws still pops cleanly: all values are
  /// deinitialized, and the arena remains reusable.
  @Test
  func scopeBodyThrowingStillPopsAcrossSlabs() async {
    struct ScopeError: Error {}
    let tracker = DeinitCounter()
    let arena = Arena(slabMinimumByteCount: 32, slabMinimumAlignment: 8)
    await #expect(throws: ScopeError.self) {
      try await arena.withScope {
        _ = arena.push(DeinitProbe(tracker: tracker))
        _ = arena.push(DeinitProbe(tracker: tracker))
        _ = arena.push(DeinitProbe(tracker: tracker))
        _ = arena.push(DeinitProbe(tracker: tracker))
        _ = arena.push(DeinitProbe(tracker: tracker))  // forces growth
        throw ScopeError()
      }
    }
    #expect(tracker.count == 5)
    await arena.withScope {
      let ref = arena.push(Int64(42))
      #expect(ref.wrappedValue == 42)
    }
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

private final class DeinitOrderTracker {
  var order: [Int] = []
}

private final class OrderedDeinitProbe {
  let id: Int
  let tracker: DeinitOrderTracker
  init(id: Int, tracker: DeinitOrderTracker) {
    self.id = id
    self.tracker = tracker
  }
  deinit {
    tracker.order.append(id)
  }
}
