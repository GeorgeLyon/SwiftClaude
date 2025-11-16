import Testing

@testable import SchemaCodingSupport

// MARK: - Basic Reference Value Semantics

@Suite("Basic Reference Value Semantics")
struct BasicReferenceValueSemanticsTests {

  @Test
  func referenceIsCopyable() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = ref1  // Copy the reference

    // Both references should exist independently as value types
    let arena = Arena(archetype)

    // Should be able to access through both references
    _ = arena[ref1]
    _ = arena[ref2]
  }

  @Test
  func copiedReferencesAccessSameMemory() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = ref1  // Copy the reference

    let arena = Arena(archetype)

    // Write through ref1
    arena.withValue(ref1) { $0 = 42 }

    // Read through ref2 should see the same value
    let value = arena[ref2]
    #expect(value == 42)
  }

  @Test
  func copiedReferencesAreIndependentValues() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = ref1  // Copy the reference

    // Modifying ref1's fields (if we could) wouldn't affect ref2
    // This is more of a conceptual test - references are immutable structs
    // The fact that we can copy them proves they're value types

    let arena = Arena(archetype)
    _ = arena[ref1]
    _ = arena[ref2]
  }

}

// MARK: - Reading Through References

@Suite("Reading Through References")
struct ReadingThroughReferencesTests {

  @Test
  func readIntThroughSubscript() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    // Initial value should be nil (inner optional)
    let value = arena[ref]
    #expect(value == Optional(nil))
  }

  @Test
  func readStringThroughSubscript() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = "Hello, Arena!" }

    let value = arena[ref]
    #expect(value == "Hello, Arena!")
  }

  @Test
  func readBoolThroughSubscript() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Bool?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = true }

    let value = arena[ref]
    #expect(value == true)
  }

  @Test
  func readConsistencyAcrossMultipleAccesses() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 100 }

    // Multiple reads should return the same value
    #expect(arena[ref] == 100)
    #expect(arena[ref] == 100)
    #expect(arena[ref] == 100)
  }

  @Test
  func readMultipleReferencesInSameSlab() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()
    let ref3 = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref1) { $0 = 10 }
    arena.withValue(ref2) { $0 = 20 }
    arena.withValue(ref3) { $0 = 30 }

    #expect(arena[ref1] == 10)
    #expect(arena[ref2] == 20)
    #expect(arena[ref3] == 30)
  }

}

// MARK: - Writing Through References

@Suite("Writing Through References")
struct WritingThroughReferencesTests {

  @Test
  func mutateThroughSyncWithValue() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }

    #expect(arena[ref] == 42)
  }

  @Test
  func mutateThroughAsyncWithValue() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    await arena.withValueAsync(ref) { value in
      value = "Async mutation"
    }

    #expect(arena[ref] == "Async mutation")
  }

  @Test
  func mutationPersistsAcrossAccesses() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 100 }
    #expect(arena[ref] == 100)

    arena.withValue(ref) { $0 = 200 }
    #expect(arena[ref] == 200)
  }

  @Test
  func mutationVisibleThroughSameReference() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }

    let value = arena.withValue(ref) { $0 }
    #expect(value == 42)
  }

  @Test
  func mutationVisibleThroughCopiedReference() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = ref1  // Copy

    let arena = Arena(archetype)

    arena.withValue(ref1) { $0 = 999 }

    #expect(arena[ref2] == 999)
  }

  @Test
  func withValueReturnsBodyResult() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }

    let result = arena.withValue(ref) { value -> Int in
      return (value ?? 0) ?? 0
    }

    #expect(result == 42)
  }

}

// MARK: - Multiple References to Same Location

@Suite("Multiple References to Same Location")
struct MultipleReferencesToSameLocationTests {

  @Test
  func copiedReferencesShareMemory() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let original = slab.append()
    let copy1 = original
    let copy2 = original

    let arena = Arena(archetype)

    arena.withValue(original) { $0 = 123 }

    #expect(arena[copy1] == 123)
    #expect(arena[copy2] == 123)
  }

  @Test
  func mutationThroughOneCopyVisibleThroughOthers() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)

    let ref1 = slab.append()
    let ref2 = ref1
    let ref3 = ref1

    let arena = Arena(archetype)

    arena.withValue(ref2) { $0 = "Modified through ref2" }

    #expect(arena[ref1] == "Modified through ref2")
    #expect(arena[ref3] == "Modified through ref2")
  }

  @Test
  func multipleReferencesWithDifferentTypes() async throws {
    let archetype = Arena.Archetype()
    let intSlab = archetype.typedSlab(Int?.self)
    let stringSlab = archetype.typedSlab(String?.self)

    let intRef1 = intSlab.append()
    let intRef2 = intRef1

    let stringRef1 = stringSlab.append()
    let stringRef2 = stringRef1

    let arena = Arena(archetype)

    arena.withValue(intRef1) { $0 = 42 }
    arena.withValue(stringRef1) { $0 = "test" }

    #expect(arena[intRef2] == 42)
    #expect(arena[stringRef2] == "test")
  }

}

// MARK: - Multiple References to Different Locations

@Suite("Multiple References to Different Locations")
struct MultipleReferencesToDifferentLocationsTests {

  @Test
  func independentReferencesInSameSlab() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()
    let ref3 = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref1) { $0 = 10 }
    arena.withValue(ref2) { $0 = 20 }
    arena.withValue(ref3) { $0 = 30 }

    // Each reference accesses independent memory
    #expect(arena[ref1] == 10)
    #expect(arena[ref2] == 20)
    #expect(arena[ref3] == 30)
  }

  @Test
  func mutatingOneReferenceDoesNotAffectOthers() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref1) { $0 = 100 }
    arena.withValue(ref2) { $0 = 200 }

    // Mutating ref1 should not affect ref2
    arena.withValue(ref1) { $0 = 999 }

    #expect(arena[ref1] == 999)
    #expect(arena[ref2] == 200)  // Unchanged
  }

  @Test
  func referencesAcrossDifferentSlabs() async throws {
    let archetype = Arena.Archetype()

    let intSlab = archetype.typedSlab(Int?.self)
    let stringSlab = archetype.typedSlab(String?.self)
    let boolSlab = archetype.typedSlab(Bool?.self)

    let intRef = intSlab.append()
    let stringRef = stringSlab.append()
    let boolRef = boolSlab.append()

    let arena = Arena(archetype)

    arena.withValue(intRef) { $0 = 42 }
    arena.withValue(stringRef) { $0 = "hello" }
    arena.withValue(boolRef) { $0 = true }

    #expect(arena[intRef] == 42)
    #expect(arena[stringRef] == "hello")
    #expect(arena[boolRef] == true)
  }

  @Test
  func offsetCalculationsAreCorrect() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    // Create multiple references - each should have correct offset
    let refs = (0..<10).map { _ in slab.append() }

    let arena = Arena(archetype)

    // Assign unique values to each reference
    for (index, ref) in refs.enumerated() {
      arena.withValue(ref) { $0 = index * 100 }
    }

    // Verify each reference has the correct value
    for (index, ref) in refs.enumerated() {
      #expect(arena[ref] == index * 100)
    }
  }

}

// MARK: - Reference Validation

@Suite("Reference Validation")
struct ReferenceValidationTests {

  @Test
  func validBufferIndices() async throws {
    let archetype = Arena.Archetype()

    // Create multiple slabs, each gets its own buffer index
    let slab1 = archetype.typedSlab(Int?.self)
    let slab2 = archetype.typedSlab(String?.self)
    let slab3 = archetype.typedSlab(Bool?.self)

    let ref1 = slab1.append()
    let ref2 = slab2.append()
    let ref3 = slab3.append()

    let arena = Arena(archetype)

    // All references should be valid across different buffers
    arena.withValue(ref1) { $0 = 1 }
    arena.withValue(ref2) { $0 = "two" }
    arena.withValue(ref3) { $0 = true }

    #expect(arena[ref1] == 1)
    #expect(arena[ref2] == "two")
    #expect(arena[ref3] == true)
  }

  @Test
  func firstBufferReference() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }
    #expect(arena[ref] == 42)
  }

  @Test
  func lastBufferReference() async throws {
    let archetype = Arena.Archetype()

    // Create several slabs
    _ = archetype.typedSlab(Int?.self)
    _ = archetype.typedSlab(String?.self)
    let lastSlab = archetype.typedSlab(Bool?.self)

    let ref = lastSlab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = true }
    #expect(arena[ref] == true)
  }

}

// MARK: - Reference Lifecycle

@Suite("Reference Lifecycle")
struct ReferenceLifecycleTests {

  @Test
  func referenceCreatedBeforeArenaInstantiation() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    // Create reference before arena
    let ref = slab.append()

    // Now create arena
    let arena = Arena(archetype)

    // Reference should still be valid
    arena.withValue(ref) { $0 = 42 }
    #expect(arena[ref] == 42)
  }

  @Test
  func referenceRemainsValidAfterArenaCreation() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    // Use reference multiple times after arena creation
    arena.withValue(ref) { $0 = 100 }
    #expect(arena[ref] == 100)

    arena.withValue(ref) { $0 = 200 }
    #expect(arena[ref] == 200)
  }

  @Test
  func referencesAfterArenaReset() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }
    #expect(arena[ref] == 42)

    // Reset the arena
    arena.reset()

    // After reset, value should be nil (reinitialized)
    #expect(arena[ref] == Optional(nil))

    // Should still be able to mutate
    arena.withValue(ref) { $0 = 100 }
    #expect(arena[ref] == 100)
  }

  @Test
  func multipleReferencesAcrossArenaReset() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()
    let ref3 = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref1) { $0 = 10 }
    arena.withValue(ref2) { $0 = 20 }
    arena.withValue(ref3) { $0 = 30 }

    arena.reset()

    // All should be reset to nil (inner optional)
    #expect(arena[ref1] == Optional(nil))
    #expect(arena[ref2] == Optional(nil))
    #expect(arena[ref3] == Optional(nil))
  }

}

// MARK: - Type Safety

@Suite("Type Safety")
struct TypeSafetyTests {

  @Test
  func intReferencesAreTypeSafe() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }
    let value = arena[ref]
    #expect(value == 42)
  }

  @Test
  func stringReferencesAreTypeSafe() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = "type safe" }
    let value = arena[ref]
    #expect(value == "type safe")
  }

  @Test
  func customStructReferences() async throws {
    struct Point: Equatable {
      var x: Int
      var y: Int
    }

    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Point?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = Point(x: 10, y: 20) }

    let value = arena[ref]
    #expect(value == Point(x: 10, y: 20))
  }

  @Test
  func differentTypesInDifferentSlabs() async throws {
    let archetype = Arena.Archetype()

    let intSlab = archetype.typedSlab(Int?.self)
    let stringSlab = archetype.typedSlab(String?.self)
    let boolSlab = archetype.typedSlab(Bool?.self)

    let intRef = intSlab.append()
    let stringRef = stringSlab.append()
    let boolRef = boolSlab.append()

    let arena = Arena(archetype)

    // Each reference is type-safe
    arena.withValue(intRef) { $0 = 42 }
    arena.withValue(stringRef) { $0 = "test" }
    arena.withValue(boolRef) { $0 = true }

    #expect(arena[intRef] == 42)
    #expect(arena[stringRef] == "test")
    #expect(arena[boolRef] == true)
  }

}

// MARK: - Edge Cases

@Suite("Edge Cases")
struct EdgeCasesTests {

  @Test
  func emptySlabNoReferences() async throws {
    let archetype = Arena.Archetype()
    _ = archetype.typedSlab(Int?.self)  // Create slab but don't append

    let arena = Arena(archetype)

    // Arena should handle empty slab gracefully
    arena.reset()
  }

  @Test
  func singleReferenceInSlab() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }
    #expect(arena[ref] == 42)
  }

  @Test
  func manyReferencesInSlab() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    // Create many references
    let refs = (0..<100).map { _ in slab.append() }

    let arena = Arena(archetype)

    // Assign values
    for (index, ref) in refs.enumerated() {
      arena.withValue(ref) { $0 = index }
    }

    // Verify all values
    for (index, ref) in refs.enumerated() {
      #expect(arena[ref] == index)
    }
  }

  @Test
  func optionalIntReferences() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()

    let arena = Arena(archetype)

    // One with value, one nil
    arena.withValue(ref1) { $0 = 42 }
    // ref2 remains nil

    #expect(arena[ref1] == 42)
    #expect(arena[ref2] == Optional(nil))
  }

  @Test
  func largeStructInArena() async throws {
    struct LargeStruct: Equatable {
      var values: [Int]
      var name: String
      var metadata: [String: String]
    }

    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(LargeStruct?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    let largeValue = LargeStruct(
      values: Array(0..<100),
      name: "Large",
      metadata: ["key1": "value1", "key2": "value2"]
    )

    arena.withValue(ref) { $0 = largeValue }

    // Verify the value was stored correctly
    let retrieved = arena[ref]
    #expect(retrieved == largeValue)
  }

}

// MARK: - Memory Layout Verification

@Suite("Memory Layout Verification")
struct MemoryLayoutVerificationTests {

  @Test
  func offsetCalculationsForInts() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()
    let ref3 = slab.append()

    let arena = Arena(archetype)

    // Set distinct values
    arena.withValue(ref1) { $0 = 111 }
    arena.withValue(ref2) { $0 = 222 }
    arena.withValue(ref3) { $0 = 333 }

    // Verify no overlap - each reference has its own memory
    #expect(arena[ref1] == 111)
    #expect(arena[ref2] == 222)
    #expect(arena[ref3] == 333)
  }

  @Test
  func offsetCalculationsForDifferentTypes() async throws {
    struct SmallStruct: Equatable {
      var a: Int
    }

    struct LargeStruct: Equatable {
      var a: Int
      var b: Int
      var c: Int
      var d: Int
    }

    let archetype = Arena.Archetype()

    let smallSlab = archetype.typedSlab(SmallStruct?.self)
    let largeSlab = archetype.typedSlab(LargeStruct?.self)

    let smallRef1 = smallSlab.append()
    let smallRef2 = smallSlab.append()

    let largeRef1 = largeSlab.append()
    let largeRef2 = largeSlab.append()

    let arena = Arena(archetype)

    arena.withValue(smallRef1) { $0 = SmallStruct(a: 1) }
    arena.withValue(smallRef2) { $0 = SmallStruct(a: 2) }

    arena.withValue(largeRef1) { $0 = LargeStruct(a: 10, b: 20, c: 30, d: 40) }
    arena.withValue(largeRef2) { $0 = LargeStruct(a: 50, b: 60, c: 70, d: 80) }

    // Verify correct spacing for each type
    #expect(arena[smallRef1] == SmallStruct(a: 1))
    #expect(arena[smallRef2] == SmallStruct(a: 2))
    #expect(arena[largeRef1] == LargeStruct(a: 10, b: 20, c: 30, d: 40))
    #expect(arena[largeRef2] == LargeStruct(a: 50, b: 60, c: 70, d: 80))
  }

  @Test
  func multipleReferencesHaveCorrectSpacing() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    let refs = (0..<20).map { _ in slab.append() }

    let arena = Arena(archetype)

    // Assign unique values based on prime numbers to detect any overlap
    let primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71]

    for (ref, prime) in zip(refs, primes) {
      arena.withValue(ref) { $0 = prime }
    }

    // Verify each reference still has its unique prime value
    for (ref, prime) in zip(refs, primes) {
      #expect(arena[ref] == prime)
    }
  }

}

// MARK: - Async Operations

@Suite("Async Operations")
struct AsyncOperationsTests {

  @Test
  func asyncWithValueMutation() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    await arena.withValueAsync(ref) { value in
      value = "Async result"
    }

    #expect(arena[ref] == "Async result")
  }

  @Test
  func asyncWithValueReturnsValue() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 42 }

    let result = await arena.withValueAsync(ref) { value -> Int in
      return (value ?? 0) ?? 0
    }

    #expect(result == 42)
  }

  @Test
  func asyncWithValueMultipleMutations() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    await arena.withValueAsync(ref) { $0 = 10 }
    #expect(arena[ref] == 10)

    await arena.withValueAsync(ref) { $0 = 20 }
    #expect(arena[ref] == 20)

    await arena.withValueAsync(ref) { $0 = 30 }
    #expect(arena[ref] == 30)
  }

  @Test
  func asyncAndSyncWithValueInterleaved() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)
    let ref = slab.append()

    let arena = Arena(archetype)

    arena.withValue(ref) { $0 = 100 }
    #expect(arena[ref] == 100)

    await arena.withValueAsync(ref) { $0 = 200 }
    #expect(arena[ref] == 200)

    arena.withValue(ref) { $0 = 300 }
    #expect(arena[ref] == 300)
  }

  @Test
  func asyncWithValueOnMultipleReferences() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)

    let ref1 = slab.append()
    let ref2 = slab.append()
    let ref3 = slab.append()

    let arena = Arena(archetype)

    await arena.withValueAsync(ref1) { $0 = "First" }
    await arena.withValueAsync(ref2) { $0 = "Second" }
    await arena.withValueAsync(ref3) { $0 = "Third" }

    #expect(arena[ref1] == "First")
    #expect(arena[ref2] == "Second")
    #expect(arena[ref3] == "Third")
  }

}

extension Arena {

  fileprivate func withValueAsync<Value: ~Copyable, T: ~Copyable>(
    _ reference: Reference<Value>, body: (inout Value) async throws -> T
  ) async rethrows -> T {
    try await withValue(reference, body: body)
  }

}
