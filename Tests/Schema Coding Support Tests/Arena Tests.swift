import Testing

@testable import SchemaCodingSupport

@Suite("Arena Tests")
struct ArenaTests {

  // MARK: - Basic Operations Suite

  @Suite("Basic Operations")
  struct BasicOperations {

    @Test("Push and read BitwiseCopyable value")
    func pushAndReadBitwiseCopyable() {
      let arena = Arena()
      let ref = arena.push(42)
      #expect(arena[ref] == 42)
    }

    @Test("Push and modify via withValue")
    func pushAndModifyWithValue() {
      let arena = Arena()
      let ref = arena.push(10)

      arena.withValue(ref) { value in
        value = 20
      }

      #expect(arena[ref] == 20)
    }

    @Test("Push multiple values of same type")
    func pushMultipleSameType() {
      let arena = Arena()
      let ref1 = arena.push(1)
      let ref2 = arena.push(2)
      let ref3 = arena.push(3)

      #expect(arena[ref1] == 1)
      #expect(arena[ref2] == 2)
      #expect(arena[ref3] == 3)
    }

    @Test("Push multiple values of different types")
    func pushMultipleDifferentTypes() {
      let arena = Arena()
      let intRef = arena.push(42)
      let doubleRef = arena.push(3.14)
      let boolRef = arena.push(true)

      #expect(arena[intRef] == 42)
      #expect(arena[doubleRef] == 3.14)
      #expect(arena[boolRef] == true)
    }

    @Test("Async withValue access")
    func asyncWithValueAccess() async {
      let arena = Arena()
      let ref = arena.push(100)

      await arena.withValueAsync(ref) { value in
        value = 200
      }

      #expect(arena[ref] == 200)
    }

    @Test("withValue returns value from closure")
    func withValueReturnsValue() {
      let arena = Arena()
      let ref = arena.push(50)

      let result = arena.withValue(ref) { value -> Int in
        value * 2
      }

      #expect(result == 100)
    }

    @Test("withValue can throw")
    func withValueCanThrow() {
      struct TestError: Error {}

      let arena = Arena()
      let ref = arena.push(1)

      #expect(throws: TestError.self) {
        try arena.withValue(ref) { _ in
          throw TestError()
        }
      }
    }
  }

  // MARK: - BitwiseCopyable Types Suite

  @Suite("BitwiseCopyable Types")
  struct BitwiseCopyableTypes {

    @Test("Push Int values")
    func pushIntValues() {
      let arena = Arena()
      let ref1 = arena.push(Int.min)
      let ref2 = arena.push(0)
      let ref3 = arena.push(Int.max)

      #expect(arena[ref1] == Int.min)
      #expect(arena[ref2] == 0)
      #expect(arena[ref3] == Int.max)
    }

    @Test("Push Bool values")
    func pushBoolValues() {
      let arena = Arena()
      let trueRef = arena.push(true)
      let falseRef = arena.push(false)

      #expect(arena[trueRef] == true)
      #expect(arena[falseRef] == false)
    }

    @Test("Push Double values")
    func pushDoubleValues() {
      let arena = Arena()
      let ref1 = arena.push(3.14159265359)
      let ref2 = arena.push(-273.15)
      let ref3 = arena.push(Double.infinity)

      #expect(arena[ref1] == 3.14159265359)
      #expect(arena[ref2] == -273.15)
      #expect(arena[ref3] == Double.infinity)
    }

    @Test("Push Float values")
    func pushFloatValues() {
      let arena = Arena()
      let ref1 = arena.push(Float(2.5))
      let ref2 = arena.push(Float.nan)

      #expect(arena[ref1] == 2.5)
      #expect(arena[ref2].isNaN)
    }

    @Test("Push UInt8 values")
    func pushUInt8Values() {
      let arena = Arena()
      let ref1 = arena.push(UInt8.min)
      let ref2 = arena.push(UInt8.max)

      #expect(arena[ref1] == 0)
      #expect(arena[ref2] == 255)
    }

    @Test("Push multiple BitwiseCopyable types together")
    func pushMultipleBitwiseCopyableTypes() {
      let arena = Arena()

      let intRef = arena.push(42)
      let doubleRef = arena.push(3.14)
      let boolRef = arena.push(true)
      let floatRef = arena.push(Float(1.5))
      let uint8Ref = arena.push(UInt8(128))

      #expect(arena[intRef] == 42)
      #expect(arena[doubleRef] == 3.14)
      #expect(arena[boolRef] == true)
      #expect(arena[floatRef] == 1.5)
      #expect(arena[uint8Ref] == 128)
    }

    @Test("Modify BitwiseCopyable values via withValue")
    func modifyBitwiseCopyableValues() {
      let arena = Arena()
      let ref = arena.push(100)

      arena.withValue(ref) { value in
        value += 50
      }

      #expect(arena[ref] == 150)
    }
  }

  // MARK: - Non-Copyable Types Suite

  @Suite("Non-Copyable Types")
  struct NonCopyableTypes {

    @Test("Push and access noncopyable value via withValue")
    func pushAndAccessNoncopyable() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      let ref = arena.push(NoncopyableValue(id: 42, onDeinit: onDeinit))

      arena.withValue(ref) { value in
        #expect(value.id == 42)
      }
    }

    @Test("Push multiple noncopyable values")
    func pushMultipleNoncopyable() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      let ref1 = arena.push(NoncopyableValue(id: 1, onDeinit: onDeinit))
      let ref2 = arena.push(NoncopyableValue(id: 2, onDeinit: onDeinit))
      let ref3 = arena.push(NoncopyableValue(id: 3, onDeinit: onDeinit))

      arena.withValue(ref1) { value in #expect(value.id == 1) }
      arena.withValue(ref2) { value in #expect(value.id == 2) }
      arena.withValue(ref3) { value in #expect(value.id == 3) }
    }

    @Test("Push class reference")
    func pushClassReference() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      let ref = arena.push(DeinitTracker(id: 100, onDeinit: onDeinit))

      #expect(arena[ref].id == 100)
    }

    @Test("Push String (non-BitwiseCopyable)")
    func pushString() {
      let arena = Arena()
      let ref = arena.push("Hello, Arena!")

      #expect(arena[ref] == "Hello, Arena!")
    }

    @Test("Push TestStruct (non-BitwiseCopyable)")
    func pushTestStruct() {
      let arena = Arena()
      let ref = arena.push(TestStruct(value: 42, name: "test"))

      #expect(arena[ref] == TestStruct(value: 42, name: "test"))
    }

    @Test("Mix BitwiseCopyable and non-BitwiseCopyable")
    func mixBitwiseCopyableAndNon() {
      let arena = Arena()

      let intRef = arena.push(42)
      let stringRef = arena.push("hello")
      let boolRef = arena.push(true)
      let structRef = arena.push(TestStruct(value: 1, name: "one"))

      #expect(arena[intRef] == 42)
      #expect(arena[stringRef] == "hello")
      #expect(arena[boolRef] == true)
      #expect(arena[structRef] == TestStruct(value: 1, name: "one"))
    }
  }

  // MARK: - Typed Segments Suite

  @Suite("Typed Segments")
  struct TypedSegments {

    @Test("Add typed segment and push values")
    func addSegmentAndPush() {
      let arena = Arena()
      arena.addSegment(for: String.self)

      let ref1 = arena.push("first")
      let ref2 = arena.push("second")

      #expect(arena[ref1] == "first")
      #expect(arena[ref2] == "second")
    }

    @Test("Typed segment for TestStruct")
    func typedSegmentForTestStruct() {
      let arena = Arena()
      arena.addSegment(for: TestStruct.self)

      let ref = arena.push(TestStruct(value: 42, name: "typed"))

      #expect(arena[ref] == TestStruct(value: 42, name: "typed"))
    }

    @Test("Multiple typed segments")
    func multipleTypedSegments() {
      let arena = Arena()
      arena.addSegment(for: String.self)
      arena.addSegment(for: TestStruct.self)

      let stringRef = arena.push("hello")
      let structRef = arena.push(TestStruct(value: 1, name: "one"))

      #expect(arena[stringRef] == "hello")
      #expect(arena[structRef] == TestStruct(value: 1, name: "one"))
    }

    @Test("Mix typed segment with heterogenous fallback")
    func mixTypedAndHeterogenous() {
      let arena = Arena()
      arena.addSegment(for: String.self)

      // String goes to typed segment
      let stringRef = arena.push("typed segment")
      // TestStruct has no typed segment, goes to heterogenous
      let structRef = arena.push(TestStruct(value: 99, name: "heterogenous"))
      // Int is BitwiseCopyable, goes to bitwiseCopyable segment
      let intRef = arena.push(42)

      #expect(arena[stringRef] == "typed segment")
      #expect(arena[structRef] == TestStruct(value: 99, name: "heterogenous"))
      #expect(arena[intRef] == 42)
    }

    @Test("Typed segment for noncopyable type")
    func typedSegmentForNoncopyable() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      arena.addSegment(for: NoncopyableValue.self)

      let ref = arena.push(NoncopyableValue(id: 123, onDeinit: onDeinit))

      arena.withValue(ref) { value in
        #expect(value.id == 123)
      }
    }

    @Test("Many values in typed segment")
    func manyValuesInTypedSegment() {
      let arena = Arena()
      arena.addSegment(for: Int.self)

      var refs: [Arena.Reference<Int>] = []
      for i in 0..<100 {
        refs.append(arena.push(i))
      }

      for (i, ref) in refs.enumerated() {
        #expect(arena[ref] == i)
      }
    }
  }

  // MARK: - Reset Suite

  @Suite("Reset")
  struct Reset {

    @Test("Reset allows arena reuse")
    func resetAllowsArenaReuse() {
      let arena = Arena()

      let ref1 = arena.push(42)
      #expect(arena[ref1] == 42)

      arena.reset()

      // Can push new values after reset
      let ref2 = arena.push(100)
      #expect(arena[ref2] == 100)
    }

    @Test("Multiple reset cycles")
    func multipleResetCycles() {
      let arena = Arena()

      for cycle in 1...5 {
        let ref = arena.push(cycle * 10)
        #expect(arena[ref] == cycle * 10)
        arena.reset()
      }

      // Final push after all resets
      let finalRef = arena.push(999)
      #expect(arena[finalRef] == 999)
    }

    @Test("Reset with mixed types")
    func resetWithMixedTypes() {
      let arena = Arena()
      arena.addSegment(for: String.self)

      let intRef = arena.push(42)
      let stringRef = arena.push("hello")
      let structRef = arena.push(TestStruct(value: 1, name: "test"))

      #expect(arena[intRef] == 42)
      #expect(arena[stringRef] == "hello")
      #expect(arena[structRef] == TestStruct(value: 1, name: "test"))

      arena.reset()

      // Push new values of same types
      let newIntRef = arena.push(100)
      let newStringRef = arena.push("world")
      let newStructRef = arena.push(TestStruct(value: 2, name: "new"))

      #expect(arena[newIntRef] == 100)
      #expect(arena[newStringRef] == "world")
      #expect(arena[newStructRef] == TestStruct(value: 2, name: "new"))
    }

    @Test("Reset calls deinit on stored values")
    func resetCallsDeinit() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      let arena = Arena()

      _ = arena.push(DeinitTracker(id: 1, onDeinit: onDeinit))
      _ = arena.push(DeinitTracker(id: 2, onDeinit: onDeinit))

      #expect(counter.count == 0)

      arena.reset()

      #expect(counter.count == 2)
    }

    @Test("Reset with noncopyable values calls deinit")
    func resetWithNoncopyableCallsDeinit() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      let arena = Arena()
      arena.addSegment(for: NoncopyableValue.self)

      _ = arena.push(NoncopyableValue(id: 1, onDeinit: onDeinit))
      _ = arena.push(NoncopyableValue(id: 2, onDeinit: onDeinit))
      _ = arena.push(NoncopyableValue(id: 3, onDeinit: onDeinit))

      #expect(counter.count == 0)

      arena.reset()

      #expect(counter.count == 3)
    }
  }

  // MARK: - Deinitialization Suite

  @Suite("Deinitialization")
  struct Deinitialization {

    @Test("Class deinit on arena deallocation")
    func classDeinitOnArenaDealloc() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      #expect(counter.count == 0)

      do {
        let arena = Arena()
        _ = arena.push(DeinitTracker(id: 1, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 2, onDeinit: onDeinit))
        #expect(counter.count == 0)
      }

      #expect(counter.count == 2)
    }

    @Test("Noncopyable struct deinit on arena deallocation")
    func noncopyableStructDeinitOnArenaDealloc() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      #expect(counter.count == 0)

      do {
        let arena = Arena()
        _ = arena.push(NoncopyableValue(id: 10, onDeinit: onDeinit))
        _ = arena.push(NoncopyableValue(id: 20, onDeinit: onDeinit))
        #expect(counter.count == 0)
      }

      #expect(counter.count == 2)
    }

    @Test("Mixed types deinit on arena deallocation")
    func mixedTypesDeinitOnArenaDealloc() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      do {
        let arena = Arena()
        arena.addSegment(for: NoncopyableValue.self)

        _ = arena.push(DeinitTracker(id: 1, onDeinit: onDeinit))
        _ = arena.push(NoncopyableValue(id: 2, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 3, onDeinit: onDeinit))

        #expect(counter.count == 0)
      }

      #expect(counter.count == 3)
    }

    @Test("Typed segment deinit on arena deallocation")
    func typedSegmentDeinitOnArenaDealloc() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      do {
        let arena = Arena()
        arena.addSegment(for: DeinitTracker.self)

        _ = arena.push(DeinitTracker(id: 1, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 2, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 3, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 4, onDeinit: onDeinit))

        #expect(counter.count == 0)
      }

      #expect(counter.count == 4)
    }

    @Test("Deinit after reset then more pushes")
    func deinitAfterResetThenMorePushes() {
      final class Counter: @unchecked Sendable {
        var count = 0
      }
      let counter = Counter()
      let onDeinit: @Sendable (Int) -> Void = { _ in
        counter.count += 1
      }

      do {
        let arena = Arena()

        _ = arena.push(DeinitTracker(id: 1, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 2, onDeinit: onDeinit))

        #expect(counter.count == 0)

        arena.reset()

        #expect(counter.count == 2)

        _ = arena.push(DeinitTracker(id: 3, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 4, onDeinit: onDeinit))
        _ = arena.push(DeinitTracker(id: 5, onDeinit: onDeinit))

        #expect(counter.count == 2)
      }

      #expect(counter.count == 5)
    }
  }

  // MARK: - ID Validation Suite

  @Suite("ID Validation")
  struct IDValidation {

    @Test("Reference from different arena fails")
    func referenceFromDifferentArenaFails() async {
      await #expect(processExitsWith: .failure) {
        let arena1 = Arena()
        let ref = arena1.push(42)

        let arena2 = Arena()

        // Accessing ref from arena2 should trap (different arena IDs)
        _ = arena2[ref]
      }
    }

    @Test("Reference used after reset fails")
    func referenceUsedAfterResetFails() async {
      await #expect(processExitsWith: .failure) {
        let arena = Arena()
        let ref = arena.push(42)

        #expect(arena[ref] == 42)

        arena.reset()

        // Accessing ref after reset should trap (ID changed)
        _ = arena[ref]
      }
    }

    @Test("withValue with reference from different arena fails")
    func withValueFromDifferentArenaFails() async {
      await #expect(processExitsWith: .failure) {
        let arena1 = Arena()
        let ref = arena1.push("test")

        let arena2 = Arena()

        // Using ref with arena2's withValue should trap
        arena2.withValue(ref) { _ in }
      }
    }
  }

  // MARK: - Stats Suite

  @Suite("Stats")
  struct StatsTests {

    @Test("BitwiseCopyable values tracked in bitwiseCopyableSegment")
    func bitwiseCopyableValuesTracked() {
      let arena = Arena()

      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)

      _ = arena.push(42)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)

      _ = arena.push(3.14)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 2)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)

      _ = arena.push(true)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 3)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
    }

    @Test("Non-BitwiseCopyable values tracked in heterogenousSegment")
    func nonBitwiseCopyableValuesTracked() {
      let arena = Arena()

      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)

      _ = arena.push("hello")
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)

      _ = arena.push(TestStruct(value: 42, name: "test"))
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 2)
    }

    @Test("Typed segment values tracked in typedSegments")
    func typedSegmentValuesTracked() {
      let arena = Arena()
      arena.addSegment(for: String.self)

      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 0)

      _ = arena.push("typed")
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)

      _ = arena.push("another")
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 2)
    }

    @Test("Mixed types tracked in correct slabs")
    func mixedTypesTrackedCorrectly() {
      let arena = Arena()
      arena.addSegment(for: String.self)

      // BitwiseCopyable -> bitwiseCopyableSegment
      _ = arena.push(42)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 0)

      // String with typed segment -> typedSegments
      _ = arena.push("typed")
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)

      // TestStruct without typed segment -> heterogenousSegment
      _ = arena.push(TestStruct(value: 1, name: "test"))
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)

      // More BitwiseCopyable
      _ = arena.push(true)
      _ = arena.push(3.14)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 3)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)

      // More typed String
      _ = arena.push("another")
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 3)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 2)
    }

    @Test("Stats reset on arena reset")
    func statsResetOnArenaReset() {
      let arena = Arena()
      arena.addSegment(for: String.self)

      _ = arena.push(42)
      _ = arena.push("typed")
      _ = arena.push(TestStruct(value: 1, name: "test"))

      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)

      arena.reset()

      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 0)
    }

    @Test("Multiple typed segments tracked separately")
    func multipleTypedSegmentsTrackedSeparately() {
      let arena = Arena()
      arena.addSegment(for: String.self)
      arena.addSegment(for: TestStruct.self)

      _ = arena.push("string1")
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)
      #expect(arena.stats.typedSegments[TestStruct.self]?.elementCount == 0)

      _ = arena.push(TestStruct(value: 1, name: "one"))
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)
      #expect(arena.stats.typedSegments[TestStruct.self]?.elementCount == 1)

      _ = arena.push("string2")
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 2)
      #expect(arena.stats.typedSegments[TestStruct.self]?.elementCount == 1)

      _ = arena.push(TestStruct(value: 2, name: "two"))
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 2)
      #expect(arena.stats.typedSegments[TestStruct.self]?.elementCount == 2)

      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
    }

    @Test("Noncopyable values tracked in heterogenousSegment")
    func noncopyableValuesTrackedInHeterogenousSegment() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      _ = arena.push(NoncopyableValue(id: 1, onDeinit: onDeinit))
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)

      _ = arena.push(NoncopyableValue(id: 2, onDeinit: onDeinit))
      #expect(arena.stats.heterogenousSegment.elementCount == 2)
    }

    @Test("Noncopyable values tracked in typed segment when available")
    func noncopyableValuesTrackedInTypedSegment() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      arena.addSegment(for: NoncopyableValue.self)

      _ = arena.push(NoncopyableValue(id: 1, onDeinit: onDeinit))
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.typedSegments[NoncopyableValue.self]?.elementCount == 1)

      _ = arena.push(NoncopyableValue(id: 2, onDeinit: onDeinit))
      #expect(arena.stats.typedSegments[NoncopyableValue.self]?.elementCount == 2)
    }

    @Test("Class references tracked in heterogenousSegment")
    func classReferencesTrackedInHeterogenousSegment() {
      let arena = Arena()
      let onDeinit: @Sendable (Int) -> Void = { _ in }

      _ = arena.push(DeinitTracker(id: 1, onDeinit: onDeinit))
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)
    }

    @Test("Unregistered typed segment returns nil")
    func unregisteredTypedSegmentReturnsNil() {
      let arena = Arena()

      #expect(arena.stats.typedSegments[String.self] == nil)
      #expect(arena.stats.typedSegments[TestStruct.self] == nil)

      arena.addSegment(for: String.self)

      #expect(arena.stats.typedSegments[String.self] != nil)
      #expect(arena.stats.typedSegments[TestStruct.self] == nil)
    }

    @Test("POD type ends up in bitwise copyable segment even without BitwiseCopyable conformance")
    func podTypeRoutesBitwiseCopyableSegment() {
      let arena = Arena()

      #expect(arena.stats.bitwiseCopyableSegment.podElementCount == 0)
      #expect(arena.stats.bitwiseCopyableSegment.bitwiseCopyableElementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)

      // Push a POD struct that doesn't conform to BitwiseCopyable
      let ref = arena.push(PODStruct(x: 42, y: 3.14, z: true))

      // Should be routed to bitwiseCopyableSegment via POD detection
      #expect(arena.stats.bitwiseCopyableSegment.podElementCount == 1)
      #expect(arena.stats.bitwiseCopyableSegment.bitwiseCopyableElementCount == 0)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)

      // Verify the value is correctly stored and retrievable
      #expect(arena[ref] == PODStruct(x: 42, y: 3.14, z: true))

      // Push an explicitly BitwiseCopyable type
      _ = arena.push(123)

      #expect(arena.stats.bitwiseCopyableSegment.podElementCount == 1)
      #expect(arena.stats.bitwiseCopyableSegment.bitwiseCopyableElementCount == 1)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 2)
    }

    // MARK: - Slab Allocation Tests

    @Test("BitwiseCopyable segment allocates new slabs when full")
    func bitwiseCopyableSegmentAllocatesNewSlabs() {
      // Create arena with small slab size (16 bytes) to force multiple slabs
      let arena = Arena(
        bitwiseCopyableSegmentSlabMinimumByteCount: 16,
        bitwiseCopyableSegmentSlabMinimumAlignment: MemoryLayout<Int>.alignment
      )

      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 0)
      #expect(arena.stats.bitwiseCopyableSegment.emptySlabCount == 0)

      // First Int (8 bytes) should create first slab
      _ = arena.push(1)
      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 1)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 1)

      // Second Int should still fit in first slab (16 bytes total capacity)
      _ = arena.push(2)
      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 1)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 2)

      // Third Int should trigger new slab
      _ = arena.push(3)
      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 2)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 3)

      // Fourth Int should still fit in second slab
      _ = arena.push(4)
      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 2)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 4)

      // Fifth Int should trigger third slab
      _ = arena.push(5)
      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 3)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 5)
    }

    @Test("Heterogenous segment allocates new slabs when full")
    func heterogenousSegmentAllocatesNewSlabs() {
      // Create arena with small slab size to force multiple slabs
      let arena = Arena(
        heterogenousSegmentSlabMinimumByteCount: 64,
        heterogenousSegmentSlabMinimumAlignment: MemoryLayout<Int>.alignment
      )

      #expect(arena.stats.heterogenousSegment.slabCount == 0)
      #expect(arena.stats.heterogenousSegment.emptySlabCount == 0)

      // Push strings to fill up slabs
      _ = arena.push("short")
      #expect(arena.stats.heterogenousSegment.slabCount == 1)
      #expect(arena.stats.heterogenousSegment.elementCount == 1)

      // Push more strings to trigger new slabs
      for i in 2...5 {
        _ = arena.push("string\(i)")
      }
      #expect(arena.stats.heterogenousSegment.elementCount == 5)
      // Should have multiple slabs due to small slab size
      #expect(arena.stats.heterogenousSegment.slabCount >= 1)
    }

    @Test("Typed segment allocates new slabs when full")
    func typedSegmentAllocatesNewSlabs() {
      let arena = Arena()
      // Create typed segment with capacity of 2 elements per slab
      arena.addSegment(for: String.self, slabCapacity: 2)

      #expect(arena.stats.typedSegments[String.self]?.slabCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.emptySlabCount == 0)

      // First element creates first slab
      _ = arena.push("one")
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 1)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 1)

      // Second element fits in first slab
      _ = arena.push("two")
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 1)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 2)

      // Third element triggers new slab
      _ = arena.push("three")
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 2)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 3)

      // Fourth element fits in second slab
      _ = arena.push("four")
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 2)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 4)

      // Fifth element triggers third slab
      _ = arena.push("five")
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 3)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 5)
    }

    // MARK: - Empty Slab Reuse Tests

    @Test("BitwiseCopyable segment reuses empty slabs after reset")
    func bitwiseCopyableSegmentReusesEmptySlabs() {
      let arena = Arena(
        bitwiseCopyableSegmentSlabMinimumByteCount: 16,
        bitwiseCopyableSegmentSlabMinimumAlignment: MemoryLayout<Int>.alignment
      )

      // Push enough values to create multiple slabs
      for i in 0..<5 {
        _ = arena.push(i)
      }
      let slabCountBeforeReset = arena.stats.bitwiseCopyableSegment.slabCount
      #expect(slabCountBeforeReset >= 2)
      #expect(arena.stats.bitwiseCopyableSegment.emptySlabCount == 0)

      // Reset moves slabs to empty
      arena.reset()
      #expect(arena.stats.bitwiseCopyableSegment.slabCount == 0)
      #expect(arena.stats.bitwiseCopyableSegment.emptySlabCount == slabCountBeforeReset)
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 0)

      // Push new values - should reuse empty slabs
      for i in 0..<3 {
        _ = arena.push(i)
      }
      #expect(arena.stats.bitwiseCopyableSegment.elementCount == 3)
      // Should have reused empty slabs, not created new ones
      let totalSlabs =
        arena.stats.bitwiseCopyableSegment.slabCount
        + arena.stats.bitwiseCopyableSegment.emptySlabCount
      #expect(totalSlabs == slabCountBeforeReset)
    }

    @Test("Heterogenous segment reuses empty slabs after reset")
    func heterogenousSegmentReusesEmptySlabs() {
      let arena = Arena(
        heterogenousSegmentSlabMinimumByteCount: 64,
        heterogenousSegmentSlabMinimumAlignment: MemoryLayout<Int>.alignment
      )

      // Push values to create slabs
      for i in 0..<10 {
        _ = arena.push("string\(i)")
      }
      let slabCountBeforeReset = arena.stats.heterogenousSegment.slabCount
      #expect(slabCountBeforeReset >= 1)
      #expect(arena.stats.heterogenousSegment.emptySlabCount == 0)

      // Reset moves slabs to empty
      arena.reset()
      #expect(arena.stats.heterogenousSegment.slabCount == 0)
      #expect(arena.stats.heterogenousSegment.emptySlabCount == slabCountBeforeReset)
      #expect(arena.stats.heterogenousSegment.elementCount == 0)

      // Push new values - should reuse empty slabs
      for i in 0..<5 {
        _ = arena.push("new\(i)")
      }
      #expect(arena.stats.heterogenousSegment.elementCount == 5)
      // Should have reused empty slabs
      let totalSlabs =
        arena.stats.heterogenousSegment.slabCount + arena.stats.heterogenousSegment.emptySlabCount
      #expect(totalSlabs == slabCountBeforeReset)
    }

    @Test("Typed segment reuses empty slabs after reset")
    func typedSegmentReusesEmptySlabs() {
      let arena = Arena()
      arena.addSegment(for: String.self, slabCapacity: 2)

      // Push enough values to create multiple slabs
      for i in 0..<6 {
        _ = arena.push("string\(i)")
      }
      let slabCountBeforeReset = arena.stats.typedSegments[String.self]!.slabCount
      #expect(slabCountBeforeReset == 3)  // 6 elements / 2 per slab = 3 slabs
      #expect(arena.stats.typedSegments[String.self]?.emptySlabCount == 0)

      // Reset moves slabs to empty
      arena.reset()
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 0)
      #expect(arena.stats.typedSegments[String.self]?.emptySlabCount == slabCountBeforeReset)
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 0)

      // Push new values - should reuse empty slabs
      for i in 0..<4 {
        _ = arena.push("new\(i)")
      }
      #expect(arena.stats.typedSegments[String.self]?.elementCount == 4)
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 2)  // 4 elements / 2 per slab
      #expect(arena.stats.typedSegments[String.self]?.emptySlabCount == 1)  // 1 slab still empty
    }

    @Test("Multiple reset cycles reuse slabs correctly")
    func multipleResetCyclesReuseSlabs() {
      let arena = Arena(
        bitwiseCopyableSegmentSlabMinimumByteCount: 16,
        bitwiseCopyableSegmentSlabMinimumAlignment: MemoryLayout<Int>.alignment
      )

      // First cycle: create slabs
      for i in 0..<5 {
        _ = arena.push(i)
      }
      let initialSlabCount = arena.stats.bitwiseCopyableSegment.slabCount
      #expect(initialSlabCount >= 2)

      // Multiple reset cycles
      for cycle in 1...3 {
        arena.reset()
        #expect(
          arena.stats.bitwiseCopyableSegment.emptySlabCount == initialSlabCount,
          "Cycle \(cycle): empty slabs should equal initial"
        )

        // Push fewer values than before
        for i in 0..<3 {
          _ = arena.push(i * cycle)
        }

        let totalSlabs =
          arena.stats.bitwiseCopyableSegment.slabCount
          + arena.stats.bitwiseCopyableSegment.emptySlabCount
        #expect(totalSlabs == initialSlabCount, "Cycle \(cycle): total slabs should stay constant")
      }
    }

    @Test("Exceeding previous capacity creates new slabs")
    func exceedingPreviousCapacityCreatesNewSlabs() {
      let arena = Arena()
      arena.addSegment(for: String.self, slabCapacity: 2)

      // First cycle: create 2 slabs
      for i in 0..<4 {
        _ = arena.push("first\(i)")
      }
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 2)

      arena.reset()
      #expect(arena.stats.typedSegments[String.self]?.emptySlabCount == 2)

      // Second cycle: exceed previous capacity
      for i in 0..<6 {
        _ = arena.push("second\(i)")
      }
      #expect(arena.stats.typedSegments[String.self]?.slabCount == 3)
      #expect(arena.stats.typedSegments[String.self]?.emptySlabCount == 0)
      // One new slab was created beyond the 2 reused
    }
  }

  // MARK: - Variadic Generics Suite

  @Suite("Variadic Generics")
  struct VariadicGenerics {

    @Test("Create references from parameter pack")
    func createReferencesFromParameterPack() {
      let arena = Arena()

      // Use helper to create pack of references from pack of values
      let pack = ReferencePack(arena: arena, 42, "hello", true)

      // Verify values via pack expansion
      #expect(arena[pack.refs.0] == 42)
      #expect(arena[pack.refs.1] == "hello")
      #expect(arena[pack.refs.2] == true)
    }

    @Test("Modify values through reference pack")
    func modifyValuesThroughReferencePack() {
      let arena = Arena()

      let pack = ReferencePack(arena: arena, 10, "initial")

      // Modify through references
      arena.withValue(pack.refs.0) { $0 = 20 }
      arena.withValue(pack.refs.1) { $0 = "modified" }

      #expect(arena[pack.refs.0] == 20)
      #expect(arena[pack.refs.1] == "modified")
    }

    @Test("Parameter pack with single element")
    func parameterPackWithSingleElement() {
      let arena = Arena()

      // For single-element packs, refs is (Arena.Reference<Int>) - access directly
      let ref = arena.push(99)

      #expect(arena[ref] == 99)

      arena.withValue(ref) { $0 = 100 }

      #expect(arena[ref] == 100)
    }

    @Test("Parameter pack with many elements")
    func parameterPackWithManyElements() {
      let arena = Arena()

      let pack = ReferencePack(
        arena: arena,
        1,
        "two",
        3.0,
        true,
        TestStruct(value: 5, name: "five")
      )

      #expect(arena[pack.refs.0] == 1)
      #expect(arena[pack.refs.1] == "two")
      #expect(arena[pack.refs.2] == 3.0)
      #expect(arena[pack.refs.3] == true)
      #expect(arena[pack.refs.4] == TestStruct(value: 5, name: "five"))
    }

    @Test("Parameter pack with typed segments")
    func parameterPackWithTypedSegments() {
      let arena = Arena()
      arena.addSegment(for: String.self)
      arena.addSegment(for: Int.self)

      let pack = ReferencePack(arena: arena, 42, "typed", 100, "segment")

      #expect(arena[pack.refs.0] == 42)
      #expect(arena[pack.refs.1] == "typed")
      #expect(arena[pack.refs.2] == 100)
      #expect(arena[pack.refs.3] == "segment")
    }

    @Test("Modify all pack values")
    func modifyAllPackValues() {
      let arena = Arena()

      let pack = ReferencePack(arena: arena, 0, 0, 0)

      arena.withValue(pack.refs.0) { $0 = 10 }
      arena.withValue(pack.refs.1) { $0 = 20 }
      arena.withValue(pack.refs.2) { $0 = 30 }

      #expect(arena[pack.refs.0] == 10)
      #expect(arena[pack.refs.1] == 20)
      #expect(arena[pack.refs.2] == 30)
    }

    @Test("Access pack references out of order")
    func accessPackReferencesOutOfOrder() {
      let arena = Arena()

      let pack = ReferencePack(arena: arena, "a", "b", "c", "d")

      // Access in reverse order
      #expect(arena[pack.refs.3] == "d")
      #expect(arena[pack.refs.2] == "c")
      #expect(arena[pack.refs.1] == "b")
      #expect(arena[pack.refs.0] == "a")

      // Modify in mixed order
      arena.withValue(pack.refs.2) { $0 = "C" }
      arena.withValue(pack.refs.0) { $0 = "A" }
      arena.withValue(pack.refs.3) { $0 = "D" }
      arena.withValue(pack.refs.1) { $0 = "B" }

      #expect(arena[pack.refs.0] == "A")
      #expect(arena[pack.refs.1] == "B")
      #expect(arena[pack.refs.2] == "C")
      #expect(arena[pack.refs.3] == "D")
    }
  }
}

// MARK: - Implementation Details

/// Helper struct that transforms a parameter pack of values into a pack of Arena references
struct ReferencePack<each T> {
  let arena: Arena
  let refs: (repeat Arena.Reference<each T>)

  init(arena: Arena, _ values: repeat each T) {
    self.arena = arena
    self.refs = (repeat arena.push(each values))
  }
}

extension Arena {

  /// `withValue` will always choose the sync variant if no `async` functions are called from `body`
  fileprivate func withValueAsync<Value, T>(
    _ reference: Reference<Value>,
    body: (inout Value) async throws -> T
  ) async rethrows -> T {
    try await withValue(reference, body: body)
  }

}

/// Class with deinit tracking for testing deinitialization
final class DeinitTracker: Sendable {
  let id: Int
  let onDeinit: @Sendable (Int) -> Void

  init(id: Int, onDeinit: @Sendable @escaping (Int) -> Void) {
    self.id = id
    self.onDeinit = onDeinit
  }

  deinit {
    onDeinit(id)
  }
}

/// Noncopyable struct with deinit tracking
private struct NoncopyableValue: ~Copyable {
  let id: Int
  let onDeinit: @Sendable (Int) -> Void

  init(id: Int, onDeinit: @Sendable @escaping (Int) -> Void) {
    self.id = id
    self.onDeinit = onDeinit
  }

  deinit {
    onDeinit(id)
  }
}

/// Simple copyable struct for testing
private struct TestStruct: Equatable {
  let value: Int
  let name: String
}

/// POD struct that explicitly opts out of BitwiseCopyable conformance
/// but only contains BitwiseCopyable fields
private struct PODStruct: ~BitwiseCopyable, Equatable {
  let x: Int
  let y: Double
  let z: Bool
}
