import Testing

@testable import SchemaCodingSupport

// MARK: - Arena Creation

@Suite("Arena Creation")
struct ArenaCreationTests {

  @Test
  func createBasicArena() async throws {
    let archetype = Arena.Archetype()
    let arena = Arena(archetype)

    // Arena should be successfully created and can be reset
    arena.reset()
  }

  @Test
  func createArenaWithTypedSlab() async throws {
    let archetype = Arena.Archetype()
    let intSlab = archetype.typedSlab(Int?.self)

    // Add some references to the slab
    _ = intSlab.append()
    _ = intSlab.append()
    _ = intSlab.append()

    let arena = Arena(archetype)
    arena.reset()
  }

  @Test
  func createArenaWithMultipleSlabs() async throws {
    let archetype = Arena.Archetype()

    let intSlab = archetype.typedSlab(Int?.self)
    let stringSlab = archetype.typedSlab(String?.self)
    let boolSlab = archetype.typedSlab(Bool?.self)

    _ = intSlab.append()
    _ = stringSlab.append()
    _ = boolSlab.append()

    let arena = Arena(archetype)
    arena.reset()
  }

}

// MARK: - Archetype Exit Tests

@Suite("Archetype Exit Tests")
struct ArchetypeExitTests {

  @Test
  func archetypeStartsMutable() async throws {
    let archetype = Arena.Archetype()

    // Should be able to add slabs before arena creation
    _ = archetype.typedSlab(Int?.self)
    _ = archetype.typedSlab(String?.self)
  }

  @Test
  func archetypeBecomesImmutableAfterArenaCreation() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    // Can add items before arena creation
    _ = slab.append()
    _ = slab.append()

    // Create arena - this should make archetype immutable
    let arena = Arena(archetype)
    arena.reset()

    // After arena creation, the archetype's slabs have been consumed
    // The archetype is no longer mutable (though we can't directly test the flag)
  }

  @Test
  func multipleSlabsBeforeArenaCreation() async throws {
    let archetype = Arena.Archetype()

    // Add multiple slabs before arena creation (should all succeed)
    let slab1 = archetype.typedSlab(Int?.self)
    let slab2 = archetype.typedSlab(String?.self)
    let slab3 = archetype.typedSlab(Bool?.self)

    _ = slab1.append()
    _ = slab2.append()
    _ = slab3.append()

    // Create arena with all slabs
    let arena = Arena(archetype)
    arena.reset()
  }

}

// MARK: - Slab Exit Tests

@Suite("Slab Exit Tests")
struct SlabExitTests {

  @Test
  func typedSlabCanAppendBeforeArenaCreation() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    // Should be able to append before arena/buffer allocation
    _ = slab.append()
    _ = slab.append()
    _ = slab.append()
  }

  @Test
  func typedSlabBufferAllocationSucceeds() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    _ = slab.append()
    _ = slab.append()

    // Allocate buffer - this should make slab immutable
    let buffer = slab.allocateAndInitializeBuffer()
    #expect(buffer.count > 0)

    // Buffer should be properly allocated
    #expect(buffer.baseAddress != nil)

    // Clean up
    slab.deinitializeAndDeallocate(buffer)
  }

  @Test
  func multipleTypedSlabsIndependentAllocation() async throws {
    let archetype = Arena.Archetype()

    let intSlab = archetype.typedSlab(Int?.self)
    let stringSlab = archetype.typedSlab(String?.self)

    _ = intSlab.append()
    _ = intSlab.append()
    _ = stringSlab.append()

    // Each slab can allocate independently
    let intBuffer = intSlab.allocateAndInitializeBuffer()
    let stringBuffer = stringSlab.allocateAndInitializeBuffer()

    #expect(intBuffer.count > 0)
    #expect(stringBuffer.count > 0)

    // Clean up
    intSlab.deinitializeAndDeallocate(intBuffer)
    stringSlab.deinitializeAndDeallocate(stringBuffer)
  }

  @Test
  func slabResetAfterAllocation() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Bool?.self)

    _ = slab.append()

    // Allocate buffer
    let buffer = slab.allocateAndInitializeBuffer()

    // Reset should work after allocation
    slab.reset(buffer)

    // Can reset multiple times
    slab.reset(buffer)

    // Clean up
    slab.deinitializeAndDeallocate(buffer)
  }

}

// MARK: - Arena Lifecycle

@Suite("Arena Lifecycle")
struct ArenaLifecycleTests {

  @Test
  func arenaCanBeReset() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(Int?.self)

    _ = slab.append()
    _ = slab.append()

    let arena = Arena(archetype)

    // Reset should not crash
    arena.reset()

    // Can reset multiple times
    arena.reset()
  }

  @Test
  func arenaProperlyDeinitializes() async throws {
    let archetype = Arena.Archetype()
    let slab = archetype.typedSlab(String?.self)

    _ = slab.append()

    do {
      let arena = Arena(archetype)
      arena.reset()
      // Arena will deinitialize at end of scope
    }

    // If we get here without crash, deinitialization worked
  }

  @Test
  func emptyArenaLifecycle() async throws {
    let archetype = Arena.Archetype()

    // Create arena with no additional slabs (only default slabs)
    let arena = Arena(archetype)

    // Should handle reset on empty arena
    arena.reset()
  }

  @Test
  func multipleSlabsLifecycle() async throws {
    let archetype = Arena.Archetype()

    let intSlab = archetype.typedSlab(Int?.self)
    let stringSlab = archetype.typedSlab(String?.self)
    let boolSlab = archetype.typedSlab(Bool?.self)

    _ = intSlab.append()
    _ = intSlab.append()
    _ = stringSlab.append()
    _ = boolSlab.append()
    _ = boolSlab.append()
    _ = boolSlab.append()

    let arena = Arena(archetype)

    // Reset with multiple slabs
    arena.reset()
    arena.reset()
  }

}
