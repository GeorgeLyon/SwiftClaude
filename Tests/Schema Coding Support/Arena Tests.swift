import SchemaCodingSupport
import Testing

@Suite("Arena Tests")
struct ArenaTests {

  @Suite("Basic Allocation")
  struct BasicAllocationTests {

    @Test("Allocate single BitwiseCopyable value")
    func allocateSingleBitwiseCopyable() {
      var arena = Arena()
      let ref = arena.allocate(42)
      #expect(arena[ref] == 42)
    }

    @Test("Allocate single non-BitwiseCopyable value")
    func allocateSingleNonBitwiseCopyable() {
      var arena = Arena()
      let ref = arena.allocate("Hello")
      #expect(arena[ref] == "Hello")
    }

    @Test("Allocate multiple BitwiseCopyable values")
    func allocateMultipleBitwiseCopyable() {
      var arena = Arena()
      let ref1 = arena.allocate(1)
      let ref2 = arena.allocate(2)
      let ref3 = arena.allocate(3)

      #expect(arena[ref1] == 1)
      #expect(arena[ref2] == 2)
      #expect(arena[ref3] == 3)
    }

    @Test("Allocate multiple non-BitwiseCopyable values")
    func allocateMultipleNonBitwiseCopyable() {
      var arena = Arena()
      let ref1 = arena.allocate("first")
      let ref2 = arena.allocate("second")
      let ref3 = arena.allocate("third")

      #expect(arena[ref1] == "first")
      #expect(arena[ref2] == "second")
      #expect(arena[ref3] == "third")
    }

    @Test("Allocate mixed types")
    func allocateMixedTypes() {
      var arena = Arena()
      let intRef = arena.allocate(42)
      let stringRef = arena.allocate("test")
      let doubleRef = arena.allocate(3.14)
      let boolRef = arena.allocate(true)

      #expect(arena[intRef] == 42)
      #expect(arena[stringRef] == "test")
      #expect(arena[doubleRef] == 3.14)
      #expect(arena[boolRef] == true)
    }

  }

  @Suite("Reference Access")
  struct ReferenceAccessTests {

    @Test("Modify value through subscript")
    func modifyValueThroughSubscript() {
      var arena = Arena()
      let ref = arena.allocate(10)
      #expect(arena[ref] == 10)

      arena[ref] = 20
      #expect(arena[ref] == 20)
    }

    @Test("Modify value through withValue")
    func modifyValueThroughWithValue() {
      var arena = Arena()
      let ref = arena.allocate(100)

      arena.withValue(for: ref) { value in
        #expect(value == 100)
        value = 200
      }

      #expect(arena[ref] == 200)
    }

    @Test("Return value from withValue")
    func returnValueFromWithValue() {
      var arena = Arena()
      let ref = arena.allocate("test")

      let length = arena.withValue(for: ref) { value in
        value.count
      }

      #expect(length == 4)
    }

  }

  @Suite("Arena Reset")
  struct ArenaResetTests {

    @Test("Reset arena with BitwiseCopyable values")
    func resetArenaWithBitwiseCopyable() {
      var arena = Arena()
      let ref1 = arena.allocate(1)
      let ref2 = arena.allocate(2)

      #expect(arena[ref1] == 1)
      #expect(arena[ref2] == 2)

      arena.reset()

      // After reset, allocate new values
      let ref3 = arena.allocate(3)
      #expect(arena[ref3] == 3)
    }

    @Test("Reset arena with non-BitwiseCopyable values")
    func resetArenaWithNonBitwiseCopyable() {
      var arena = Arena()
      let ref1 = arena.allocate("first")
      let ref2 = arena.allocate("second")

      #expect(arena[ref1] == "first")
      #expect(arena[ref2] == "second")

      arena.reset()

      // After reset, allocate new values
      let ref3 = arena.allocate("third")
      #expect(arena[ref3] == "third")
    }

    @Test("Reset arena with mixed types")
    func resetArenaWithMixedTypes() {
      var arena = Arena()
      _ = arena.allocate(42)
      _ = arena.allocate("test")
      _ = arena.allocate(3.14)

      arena.reset()

      // After reset, allocate new values
      let ref = arena.allocate(100)
      #expect(arena[ref] == 100)
    }

  }

  @Suite("Large Value")
  struct LargeValueTests {

    @Test
    func `Test large value`() {
      var arena = Arena()
      let value = LargeValue()
      let ref = arena.allocate(value)
      #expect(arena[ref] == value)
    }

  }

  // // MARK: - Mutation Tests

  // @Test("Mutate struct through reference")
  // func mutateStructThroughReference() throws {
  //   struct Counter {
  //     var count: Int
  //   }

  //   var arena = Arena()
  //   let ref = arena.allocate(Counter(count: 0))

  //   arena.withValue(for: ref) { counter in
  //     counter.count += 1
  //   }
  //   #expect(arena[ref].count == 1)

  //   arena.withValue(for: ref) { counter in
  //     counter.count += 1
  //   }
  //   #expect(arena[ref].count == 2)
  // }

  // @Test("Mutate array through reference")
  // func mutateArrayThroughReference() throws {
  //   var arena = Arena()
  //   let ref = arena.allocate([1, 2, 3])

  //   try arena.withValue(for: ref) { array in
  //     array.append(4)
  //   }

  //   #expect(arena[ref] == [1, 2, 3, 4])
  // }

  // // MARK: - Alignment Tests

  // @Test("Allocate types with different alignment requirements")
  // func allocateDifferentAlignments() {
  //   struct Aligned1: BitwiseCopyable {
  //     let a: UInt8
  //   }

  //   struct Aligned8: BitwiseCopyable {
  //     let a: UInt64
  //   }

  //   var arena = Arena()

  //   // Allocate in alternating pattern to test alignment handling
  //   let ref1 = arena.allocate(Aligned1(a: 1))
  //   let ref2 = arena.allocate(Aligned8(a: 100))
  //   let ref3 = arena.allocate(Aligned1(a: 2))
  //   let ref4 = arena.allocate(Aligned8(a: 200))

  //   #expect(arena[ref1].a == 1)
  //   #expect(arena[ref2].a == 100)
  //   #expect(arena[ref3].a == 2)
  //   #expect(arena[ref4].a == 200)
  // }

}

// MARK: - Support

struct LargeValue: Equatable, ~BitwiseCopyable {
  private let data = (
    Component3(),
    Component3(),
    Component3(),
    Component3(),
    Component3(),
    Component3(),
  )
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.data == rhs.data
  }
  struct Component3: Equatable {
    private let data = (
      Component2(),
      Component2(),
      Component2(),
      Component2(),
      Component2(),
      Component2(),
    )
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.data == rhs.data
    }
  }
  struct Component2: Equatable {
    private let data = (
      Component1(),
      Component1(),
      Component1(),
      Component1(),
      Component1(),
      Component1(),
    )
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.data == rhs.data
    }
  }
  struct Component1: Equatable {
    private let data = (
      UInt128.random(in: (.min)..<(.max)),
      UInt128.random(in: (.min)..<(.max)),
      UInt128.random(in: (.min)..<(.max)),
      UInt128.random(in: (.min)..<(.max)),
      UInt128.random(in: (.min)..<(.max)),
      UInt128.random(in: (.min)..<(.max)),
    )
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.data == rhs.data
    }
  }
}
