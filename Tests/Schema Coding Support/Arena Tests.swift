import Testing
import SchemaCodingSupport

@Suite("Arena Tests")
struct ArenaTests {

    // MARK: - Helper Types

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
    struct NoncopyableValue: ~Copyable {
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
    struct TestStruct: Equatable {
        let value: Int
        let name: String
    }

    // MARK: - Basic Operations Suite

    @Suite("Basic Operations")
    struct BasicOperations {

        @Test("Create archetype and arena")
        func createArchetypeAndArena() {
            let archetype = Arena.Archetype()
            let ref = archetype.allocate(String?.self)
            let arena = Arena(archetype)

            // Verify initial value is nil
            #expect(arena[ref] == nil)
        }

        @Test("Allocate and store value via withValue")
        func allocateAndStoreViaWithValue() {
            let archetype = Arena.Archetype()
            let ref = archetype.allocate(String?.self)
            let arena = Arena(archetype)

            arena.withValue(ref) { value in
                value = "Hello, Arena!"
            }
            #expect(arena[ref] == "Hello, Arena!")
        }

        @Test("Access value via withValue synchronously")
        func accessWithValueSync() {
            let archetype = Arena.Archetype()
            let ref = archetype.allocate(Int?.self)
            let arena = Arena(archetype)

            arena.withValue(ref) { value in
                value = 42
            }

            #expect(arena[ref] == 42)
        }

        @Test("Access value via withValue asynchronously")
        func accessWithValueAsync() async {
            let archetype = Arena.Archetype()
            let ref = archetype.allocate(String?.self)
            let arena = Arena(archetype)

            await arena.withValue(ref) { value in
                value = "Async value"
            }

            #expect(arena[ref] == "Async value")
        }

        @Test("Archetype becomes immutable after arena creation", .disabled("Exit test not yet supported in Swift Testing"))
        func archetypeImmutabilityAfterArenaCreation() {
            let archetype = Arena.Archetype()
            let _ = Arena(archetype)

            // Attempting to allocate after arena creation should fail
            // This would be an exit test - the program should trap/exit
            // let _ = archetype.allocate(Int?.self)  // Should trap
        }

        @Test("Multiple allocations of same type")
        func multipleAllocationsOfSameType() {
            let archetype = Arena.Archetype()
            let ref1 = archetype.allocate(Int?.self)
            let ref2 = archetype.allocate(Int?.self)
            let ref3 = archetype.allocate(Int?.self)
            let arena = Arena(archetype)

            arena.withValue(ref1) { $0 = 10 }
            arena.withValue(ref2) { $0 = 20 }
            arena.withValue(ref3) { $0 = 30 }

            #expect(arena[ref1] == 10)
            #expect(arena[ref2] == 20)
            #expect(arena[ref3] == 30)
        }

        @Test("Mixed type allocations")
        func mixedTypeAllocations() {
            let archetype = Arena.Archetype()
            let stringRef = archetype.allocate(String?.self)
            let intRef = archetype.allocate(Int?.self)
            let boolRef = archetype.allocate(Bool?.self)
            let structRef = archetype.allocate(TestStruct?.self)
            let arena = Arena(archetype)

            arena.withValue(stringRef) { $0 = "test" }
            arena.withValue(intRef) { $0 = 100 }
            arena.withValue(boolRef) { $0 = true }
            arena.withValue(structRef) { $0 = TestStruct(value: 42, name: "answer") }

            #expect(arena[stringRef] == "test")
            #expect(arena[intRef] == 100)
            #expect(arena[boolRef] == true)
            #expect(arena[structRef] == TestStruct(value: 42, name: "answer"))
        }
    }

    // MARK: - Slab Routing Suite

    @Suite("Slab Routing")
    struct SlabRouting {

        @Test("BitwiseCopyable types use BitwiseCopyableSlab")
        func bitwiseCopyableSlabRouting() {
            let archetype = Arena.Archetype()

            // BitwiseCopyable types should route to BitwiseCopyableSlab
            let intRef = archetype.allocate(Int?.self)
            let boolRef = archetype.allocate(Bool?.self)
            let doubleRef = archetype.allocate(Double?.self)

            let arena = Arena(archetype)

            arena.withValue(intRef) { $0 = 123 }
            arena.withValue(boolRef) { $0 = false }
            arena.withValue(doubleRef) { $0 = 3.14159 }

            #expect(arena[intRef] == 123)
            #expect(arena[boolRef] == false)
            #expect(arena[doubleRef] == 3.14159)
        }

        @Test("Non-BitwiseCopyable types use HeterogenousSlab by default")
        func heterogenousSlabFallback() {
            let archetype = Arena.Archetype()

            // String is not BitwiseCopyable, should use HeterogenousSlab
            let stringRef = archetype.allocate(String?.self)
            let structRef = archetype.allocate(TestStruct?.self)

            let arena = Arena(archetype)

            arena.withValue(stringRef) { $0 = "heterogenous" }
            arena.withValue(structRef) { $0 = TestStruct(value: 7, name: "lucky") }

            #expect(arena[stringRef] == "heterogenous")
            #expect(arena[structRef] == TestStruct(value: 7, name: "lucky"))
        }

        @Test("Explicit typed slab is used when added")
        func explicitTypedSlabUsage() {
            let archetype = Arena.Archetype()

            // Explicitly add a typed slab for String
            archetype.addSlab(of: String?.self)

            let stringRef1 = archetype.allocate(String?.self)
            let stringRef2 = archetype.allocate(String?.self)

            let arena = Arena(archetype)

            arena.withValue(stringRef1) { $0 = "typed slab 1" }
            arena.withValue(stringRef2) { $0 = "typed slab 2" }

            #expect(arena[stringRef1] == "typed slab 1")
            #expect(arena[stringRef2] == "typed slab 2")
        }

        @Test("Mixed slab types in single arena")
        func mixedSlabTypes() {
            let archetype = Arena.Archetype()

            // Add explicit typed slab for TestStruct
            archetype.addSlab(of: TestStruct?.self)

            // BitwiseCopyable -> BitwiseCopyableSlab
            let intRef = archetype.allocate(Int?.self)

            // Has explicit slab -> TypedSlab
            let structRef = archetype.allocate(TestStruct?.self)

            // No explicit slab, not BitwiseCopyable -> HeterogenousSlab
            let stringRef = archetype.allocate(String?.self)

            let arena = Arena(archetype)

            arena.withValue(intRef) { $0 = 999 }
            arena.withValue(structRef) { $0 = TestStruct(value: 1, name: "one") }
            arena.withValue(stringRef) { $0 = "mixed slabs" }

            #expect(arena[intRef] == 999)
            #expect(arena[structRef] == TestStruct(value: 1, name: "one"))
            #expect(arena[stringRef] == "mixed slabs")
        }
    }

    // MARK: - Typed Slab Suite

    @Suite("Typed Slabs")
    struct TypedSlabs {

        @Test("Add typed slab for copyable type")
        func typedSlabForCopyableType() {
            let archetype = Arena.Archetype()
            archetype.addSlab(of: Int?.self)

            let ref1 = archetype.allocate(Int?.self)
            let ref2 = archetype.allocate(Int?.self)
            let ref3 = archetype.allocate(Int?.self)

            let arena = Arena(archetype)

            arena.withValue(ref1) { $0 = 1 }
            arena.withValue(ref2) { $0 = 2 }
            arena.withValue(ref3) { $0 = 3 }

            #expect(arena[ref1] == 1)
            #expect(arena[ref2] == 2)
            #expect(arena[ref3] == 3)
        }

        @Test("Add typed slab for noncopyable type")
        func typedSlabForNoncopyableType() {
            let onDeinit: @Sendable (Int) -> Void = { _ in }

            let archetype = Arena.Archetype()
            archetype.addSlab(of: NoncopyableValue?.self)

            let ref1 = archetype.allocate(NoncopyableValue?.self)
            let ref2 = archetype.allocate(NoncopyableValue?.self)

            let arena = Arena(archetype)

            arena.withValue(ref1) { value in
                value = NoncopyableValue(id: 1, onDeinit: onDeinit)
            }

            arena.withValue(ref2) { value in
                value = NoncopyableValue(id: 2, onDeinit: onDeinit)
            }

            // Values should exist
            arena.withValue(ref1) { value in
                #expect(value?.id == 1)
            }

            arena.withValue(ref2) { value in
                #expect(value?.id == 2)
            }
        }

        @Test("Multiple values of same type in typed slab")
        func multipleValuesInTypedSlab() {
            let archetype = Arena.Archetype()
            archetype.addSlab(of: String?.self)

            let refs = (0..<10).map { _ in archetype.allocate(String?.self) }
            let arena = Arena(archetype)

            for (index, ref) in refs.enumerated() {
                arena.withValue(ref) { $0 = "Value \(index)" }
            }

            for (index, ref) in refs.enumerated() {
                #expect(arena[ref] == "Value \(index)")
            }
        }

        @Test("Mix typed slab with heterogenous allocations")
        func mixTypedAndHeterogenous() {
            let archetype = Arena.Archetype()

            // Add typed slab only for Bool
            archetype.addSlab(of: Bool?.self)

            let boolRef1 = archetype.allocate(Bool?.self)  // -> TypedSlab
            let boolRef2 = archetype.allocate(Bool?.self)  // -> TypedSlab
            let stringRef = archetype.allocate(String?.self)  // -> HeterogenousSlab
            let intRef = archetype.allocate(Int?.self)  // -> BitwiseCopyableSlab

            let arena = Arena(archetype)

            arena.withValue(boolRef1) { $0 = true }
            arena.withValue(boolRef2) { $0 = false }
            arena.withValue(stringRef) { $0 = "mixed" }
            arena.withValue(intRef) { $0 = 42 }

            #expect(arena[boolRef1] == true)
            #expect(arena[boolRef2] == false)
            #expect(arena[stringRef] == "mixed")
            #expect(arena[intRef] == 42)
        }
    }

    // MARK: - Reset Suite

    @Suite("Reset")
    struct Reset {

        @Test("Reset sets all values to nil")
        func resetSetsValuesToNil() {
            let archetype = Arena.Archetype()
            let stringRef = archetype.allocate(String?.self)
            let intRef = archetype.allocate(Int?.self)
            let boolRef = archetype.allocate(Bool?.self)
            let arena = Arena(archetype)

            // Set values
            arena.withValue(stringRef) { $0 = "test" }
            arena.withValue(intRef) { $0 = 100 }
            arena.withValue(boolRef) { $0 = true }

            #expect(arena[stringRef] == "test")
            #expect(arena[intRef] == 100)
            #expect(arena[boolRef] == true)

            // Reset
            arena.reset()

            // All should be nil
            #expect(arena[stringRef] == nil)
            #expect(arena[intRef] == nil)
            #expect(arena[boolRef] == nil)
        }

        @Test("Multiple reset cycles")
        func multipleResetCycles() {
            let archetype = Arena.Archetype()
            let ref = archetype.allocate(Int?.self)
            let arena = Arena(archetype)

            for cycle in 1...5 {
                arena.withValue(ref) { $0 = cycle * 10 }
                #expect(arena[ref] == cycle * 10)

                arena.reset()
                #expect(arena[ref] == nil)
            }
        }

        @Test("Arena reusability after reset")
        func arenaReusabilityAfterReset() {
            let archetype = Arena.Archetype()
            let stringRef = archetype.allocate(String?.self)
            let intRef = archetype.allocate(Int?.self)
            let arena = Arena(archetype)

            // First use
            arena.withValue(stringRef) { $0 = "first" }
            arena.withValue(intRef) { $0 = 1 }

            arena.reset()

            // Second use with different values
            arena.withValue(stringRef) { $0 = "second" }
            arena.withValue(intRef) { $0 = 2 }

            #expect(arena[stringRef] == "second")
            #expect(arena[intRef] == 2)
        }

        @Test("Reset with mixed value states")
        func resetWithMixedStates() {
            let archetype = Arena.Archetype()
            let ref1 = archetype.allocate(String?.self)
            let ref2 = archetype.allocate(String?.self)
            let ref3 = archetype.allocate(String?.self)
            let arena = Arena(archetype)

            // Set only some values
            arena.withValue(ref1) { $0 = "set" }
            // ref2 remains nil
            arena.withValue(ref3) { $0 = "also set" }

            #expect(arena[ref1] == "set")
            #expect(arena[ref2] == nil)
            #expect(arena[ref3] == "also set")

            arena.reset()

            // All should be nil
            #expect(arena[ref1] == nil)
            #expect(arena[ref2] == nil)
            #expect(arena[ref3] == nil)
        }

        @Test("Reset across different slab types")
        func resetAcrossDifferentSlabs() {
            let archetype = Arena.Archetype()
            archetype.addSlab(of: TestStruct?.self)

            let intRef = archetype.allocate(Int?.self)  // BitwiseCopyableSlab
            let stringRef = archetype.allocate(String?.self)  // HeterogenousSlab
            let structRef = archetype.allocate(TestStruct?.self)  // TypedSlab

            let arena = Arena(archetype)

            arena.withValue(intRef) { $0 = 42 }
            arena.withValue(stringRef) { $0 = "hello" }
            arena.withValue(structRef) { $0 = TestStruct(value: 1, name: "test") }

            arena.reset()

            #expect(arena[intRef] == nil)
            #expect(arena[stringRef] == nil)
            #expect(arena[structRef] == nil)
        }
    }

    // MARK: - Deinitialization Suite

    @Suite("Deinitialization")
    struct Deinitialization {

        @Test("Class deinit on arena deallocation")
        func classDeinitOnArenaDealloc() {
            final class DeinitCounter: @unchecked Sendable {
                var count = 0
            }
            let counter = DeinitCounter()
            let onDeinit: @Sendable (Int) -> Void = { _ in
                counter.count += 1
            }

            #expect(counter.count == 0)

            do {
                let archetype = Arena.Archetype()
                let ref1 = archetype.allocate(DeinitTracker?.self)
                let ref2 = archetype.allocate(DeinitTracker?.self)
                let arena = Arena(archetype)

                arena.withValue(ref1) { $0 = DeinitTracker(id: 1, onDeinit: onDeinit) }
                arena.withValue(ref2) { $0 = DeinitTracker(id: 2, onDeinit: onDeinit) }

                #expect(counter.count == 0)
            }

            // Arena should be deallocated, classes should be deinitialized
            #expect(counter.count == 2)
        }

        @Test("Noncopyable struct deinit on arena deallocation")
        func noncopyableStructDeinitOnArenaDealloc() {
            final class DeinitCounter: @unchecked Sendable {
                var count = 0
            }
            let counter = DeinitCounter()
            let onDeinit: @Sendable (Int) -> Void = { _ in
                counter.count += 1
            }

            #expect(counter.count == 0)

            do {
                let archetype = Arena.Archetype()
                let ref1 = archetype.allocate(NoncopyableValue?.self)
                let ref2 = archetype.allocate(NoncopyableValue?.self)
                let arena = Arena(archetype)

                arena.withValue(ref1) { value in
                    value = NoncopyableValue(id: 10, onDeinit: onDeinit)
                }

                arena.withValue(ref2) { value in
                    value = NoncopyableValue(id: 20, onDeinit: onDeinit)
                }

                #expect(counter.count == 0)
            }

            // Arena should be deallocated, noncopyable structs should be deinitialized
            #expect(counter.count == 2)
        }

        @Test("Deinit during reset for classes")
        func classDeinitDuringReset() {
            final class DeinitCounter: @unchecked Sendable {
                var count = 0
            }
            let counter = DeinitCounter()
            let onDeinit: @Sendable (Int) -> Void = { _ in
                counter.count += 1
            }

            let archetype = Arena.Archetype()
            let ref = archetype.allocate(DeinitTracker?.self)
            let arena = Arena(archetype)

            arena.withValue(ref) { $0 = DeinitTracker(id: 100, onDeinit: onDeinit) }
            #expect(counter.count == 0)

            arena.reset()

            // Reset should have deinitialized the class
            #expect(counter.count == 1)
        }

        @Test("Deinit during reset for noncopyable structs")
        func noncopyableStructDeinitDuringReset() {
            final class DeinitCounter: @unchecked Sendable {
                var count = 0
            }
            let counter = DeinitCounter()
            let onDeinit: @Sendable (Int) -> Void = { _ in
                counter.count += 1
            }

            let archetype = Arena.Archetype()
            let ref = archetype.allocate(NoncopyableValue?.self)
            let arena = Arena(archetype)

            arena.withValue(ref) { value in
                value = NoncopyableValue(id: 200, onDeinit: onDeinit)
            }

            #expect(counter.count == 0)

            arena.reset()

            // Reset should have deinitialized the noncopyable struct
            #expect(counter.count == 1)
        }

        @Test("Mixed class and noncopyable deinit on dealloc")
        func mixedDeinitOnDealloc() {
            final class DeinitCounter: @unchecked Sendable {
                var count = 0
            }
            let counter = DeinitCounter()
            let onDeinit: @Sendable (Int) -> Void = { _ in
                counter.count += 1
            }

            do {
                let archetype = Arena.Archetype()
                let classRef = archetype.allocate(DeinitTracker?.self)
                let noncopyableRef = archetype.allocate(NoncopyableValue?.self)
                let arena = Arena(archetype)

                arena.withValue(classRef) { $0 = DeinitTracker(id: 1, onDeinit: onDeinit) }
                arena.withValue(noncopyableRef) { value in
                    value = NoncopyableValue(id: 2, onDeinit: onDeinit)
                }

                #expect(counter.count == 0)
            }

            // Both should be deinitialized
            #expect(counter.count == 2)
        }

        @Test("Only non-nil values are deinitialized")
        func onlyNonNilValuesDeinitialized() {
            final class DeinitCounter: @unchecked Sendable {
                var count = 0
            }
            let counter = DeinitCounter()
            let onDeinit: @Sendable (Int) -> Void = { _ in
                counter.count += 1
            }

            do {
                let archetype = Arena.Archetype()
                let ref1 = archetype.allocate(DeinitTracker?.self)
                let ref2 = archetype.allocate(DeinitTracker?.self)
                let ref3 = archetype.allocate(DeinitTracker?.self)
                let arena = Arena(archetype)

                arena.withValue(ref1) { $0 = DeinitTracker(id: 1, onDeinit: onDeinit) }
                // ref2 stays nil
                arena.withValue(ref3) { $0 = DeinitTracker(id: 3, onDeinit: onDeinit) }

                #expect(counter.count == 0)
            }

            // Only IDs 1 and 3 should be deinitialized (ref2 was nil)
            #expect(counter.count == 2)
        }
    }

    // MARK: - Type Safety Suite

    @Suite("Type Safety")
    struct TypeSafety {

        @Test("Reference from different arena fails", .disabled("Exit test not yet supported in Swift Testing"))
        func referenceFromDifferentArenaFails() {
            let archetype1 = Arena.Archetype()
            let ref1 = archetype1.allocate(String?.self)
            let arena1 = Arena(archetype1)

            let archetype2 = Arena.Archetype()
            let arena2 = Arena(archetype2)

            arena1.withValue(ref1) { $0 = "test" }

            // Accessing ref1 from arena2 should trap (different archetype IDs)
            // let _ = arena2[ref1]  // Should trap
        }

        @Test("Strongly typed references prevent confusion")
        func stronglyTypedReferences() {
            let archetype = Arena.Archetype()
            let stringRef = archetype.allocate(String?.self)
            let intRef = archetype.allocate(Int?.self)
            let arena = Arena(archetype)

            arena.withValue(stringRef) { $0 = "text" }
            arena.withValue(intRef) { $0 = 42 }

            // Type system prevents using wrong reference type
            #expect(arena[stringRef] == "text")
            #expect(arena[intRef] == 42)

            // This would not compile:
            // let wrongValue: Int? = arena[stringRef]
        }

        @Test("Archetype ID validation prevents cross-arena access", .disabled("Exit test not yet supported in Swift Testing"))
        func archetypeIDValidation() {
            let archetype1 = Arena.Archetype()
            let ref = archetype1.allocate(Int?.self)
            let arena1 = Arena(archetype1)
            arena1.withValue(ref) { $0 = 100 }

            // Create a second arena from a different archetype
            let archetype2 = Arena.Archetype()
            let _ = archetype2.allocate(Int?.self)
            let arena2 = Arena(archetype2)

            // Using ref (from archetype1) with arena2 should trap
            // let _ = arena2[ref]  // Should trap due to archetype ID mismatch
        }
    }

    // MARK: - Variadic Generics Suite

    /// Helper type that stores Arena references using a parameter pack
    /// Demonstrates Swift's variadic generics with <each T> syntax
    struct ArenaReferencesPack<each T> {
        let arena: Arena
        let references: (repeat Arena.Reference<each T>)

        init(arena: Arena, _ refs: repeat Arena.Reference<each T>) {
            self.arena = arena
            self.references = (repeat each refs)
        }

        /// Set values for all references in the pack using pack expansion
        func setValues(_ values: repeat each T) {
            repeat arena.withValue(each references) { ref in
                ref = each values
            }
        }

        /// Get values from all references in the pack as a tuple using pack expansion
        func getValues() -> (repeat each T) {
            return (repeat arena[each references])
        }
    }

    @Suite("Variadic Generics")
    struct VariadicGenerics {

        @Test("Use parameter pack helper to store and access references")
        func useParameterPackHelper() {
            let archetype = Arena.Archetype()

            // Add typed slabs for specific types
            archetype.addSlab(of: String?.self)
            archetype.addSlab(of: Bool?.self)

            // Allocate references for each type - creates a pack of Reference<each T>
            // from individual types: Int?, String?, Bool?, Double?, TestStruct?
            let intRef = archetype.allocate(Int?.self)
            let stringRef = archetype.allocate(String?.self)
            let boolRef = archetype.allocate(Bool?.self)
            let doubleRef = archetype.allocate(Double?.self)
            let structRef = archetype.allocate(TestStruct?.self)

            let arena = Arena(archetype)

            // Create ArenaReferencesPack which stores the references as (repeat Reference<each T>)
            // The pack infers types: <Int?, String?, Bool?, Double?, TestStruct?>
            let pack = ArenaReferencesPack(
                arena: arena,
                intRef, stringRef, boolRef, doubleRef, structRef
            )

            // Set values using pack expansion: repeat arena.withValue(each references)
            pack.setValues(
                42,
                "variadic",
                true,
                3.14,
                TestStruct(value: 100, name: "packed")
            )

            // Get values back as (repeat each T) tuple using pack expansion
            let (int, string, bool, double, struct_) = pack.getValues()

            #expect(int == 42)
            #expect(string == "variadic")
            #expect(bool == true)
            #expect(double == 3.14)
            #expect(struct_ == TestStruct(value: 100, name: "packed"))

            // Also verify we can access individual references directly
            #expect(arena[intRef] == 42)
            #expect(arena[stringRef] == "variadic")
            #expect(arena[boolRef] == true)
            #expect(arena[doubleRef] == 3.14)
            #expect(arena[structRef] == TestStruct(value: 100, name: "packed"))
        }

        @Test("Parameter pack helper with different type combinations")
        func parameterPackWithDifferentTypes() {
            let archetype = Arena.Archetype()

            // Create references for a smaller pack of types
            let ref1 = archetype.allocate(String?.self)
            let ref2 = archetype.allocate(Int?.self)
            let ref3 = archetype.allocate(Bool?.self)

            let arena = Arena(archetype)

            // Create pack with three different types - pack infers <String?, Int?, Bool?>
            let pack = ArenaReferencesPack(arena: arena, ref1, ref2, ref3)

            // Set values using parameter pack expansion
            pack.setValues("hello", 999, false)

            // Get values back as tuple - demonstrates (repeat each T) return type
            let (str, num, flag) = pack.getValues()
            #expect(str == "hello")
            #expect(num == 999)
            #expect(flag == false)
        }

        @Test("Parameter pack with single element")
        func parameterPackWithSingleElement() {
            let archetype = Arena.Archetype()

            // Even a single type forms a valid parameter pack
            let ref = archetype.allocate(String?.self)
            let arena = Arena(archetype)

            // Parameter pack can have just one element: <String?>
            let pack = ArenaReferencesPack(arena: arena, ref)

            pack.setValues("single")

            // Single element tuple requires trailing comma
            let (value,) = pack.getValues()
            #expect(value == "single")
            #expect(arena[ref] == "single")
        }

        @Test("Transform type pack to reference pack and back to value pack")
        func transformTypePackToReferencePack() {
            let archetype = Arena.Archetype()

            // Start with conceptual type pack: <Int?, String?, Double?, Bool?>
            // Allocate creates: (repeat Arena.Reference<each T>)
            let refs = (
                archetype.allocate(Int?.self),
                archetype.allocate(String?.self),
                archetype.allocate(Double?.self),
                archetype.allocate(Bool?.self)
            )

            let arena = Arena(archetype)

            // Create pack from the tuple of references
            let (intRef, stringRef, doubleRef, boolRef) = refs
            let pack = ArenaReferencesPack(arena: arena, intRef, stringRef, doubleRef, boolRef)

            // Set values: (repeat each T) -> stored in (repeat Reference<each T>)
            pack.setValues(100, "pack", 2.5, true)

            // Get values back: (repeat Reference<each T>) -> (repeat each T)
            let values = pack.getValues()
            #expect(values.0 == 100)
            #expect(values.1 == "pack")
            #expect(values.2 == 2.5)
            #expect(values.3 == true)
        }

        @Test("Parameter pack of references across different slabs")
        func parameterPackAcrossDifferentSlabs() {
            let archetype = Arena.Archetype()

            // Add explicit typed slab for TestStruct
            archetype.addSlab(of: TestStruct?.self)

            // Create references that will be stored in different slabs:
            let intRef = archetype.allocate(Int?.self)           // BitwiseCopyableSlab
            let stringRef = archetype.allocate(String?.self)     // HeterogenousSlab
            let structRef = archetype.allocate(TestStruct?.self) // TypedSlab

            let arena = Arena(archetype)

            // Store values
            arena.withValue(intRef) { $0 = 42 }
            arena.withValue(stringRef) { $0 = "hello" }
            arena.withValue(structRef) { $0 = TestStruct(value: 99, name: "test") }

            // Verify each reference works independently
            #expect(arena[intRef] == 42)
            #expect(arena[stringRef] == "hello")
            #expect(arena[structRef] == TestStruct(value: 99, name: "test"))
        }

        @Test("Access references out of order")
        func accessReferencesOutOfOrder() {
            let archetype = Arena.Archetype()
            archetype.addSlab(of: Bool?.self)

            let ref1 = archetype.allocate(Int?.self)      // BitwiseCopyableSlab
            let ref2 = archetype.allocate(String?.self)   // HeterogenousSlab
            let ref3 = archetype.allocate(Bool?.self)     // TypedSlab
            let ref4 = archetype.allocate(Double?.self)   // BitwiseCopyableSlab

            let arena = Arena(archetype)

            // Store in one order
            arena.withValue(ref1) { $0 = 1 }
            arena.withValue(ref2) { $0 = "two" }
            arena.withValue(ref3) { $0 = true }
            arena.withValue(ref4) { $0 = 4.0 }

            // Access in different order: 4, 2, 1, 3
            #expect(arena[ref4] == 4.0)
            #expect(arena[ref2] == "two")
            #expect(arena[ref1] == 1)
            #expect(arena[ref3] == true)

            // Access in another order: 3, 3, 1, 4, 2, 2
            #expect(arena[ref3] == true)
            #expect(arena[ref3] == true)
            #expect(arena[ref1] == 1)
            #expect(arena[ref4] == 4.0)
            #expect(arena[ref2] == "two")
            #expect(arena[ref2] == "two")
        }

        @Test("Variadic withValue access out of order")
        func variadicWithValueOutOfOrder() {
            let archetype = Arena.Archetype()
            archetype.addSlab(of: TestStruct?.self)

            let ref1 = archetype.allocate(Int?.self)
            let ref2 = archetype.allocate(String?.self)
            let ref3 = archetype.allocate(TestStruct?.self)

            let arena = Arena(archetype)

            // Set values using withValue
            arena.withValue(ref1) { value in value = 100 }
            arena.withValue(ref2) { value in value = "value" }
            arena.withValue(ref3) { value in value = TestStruct(value: 5, name: "five") }

            // Access out of order: 3, 1, 2
            arena.withValue(ref3) { value in
                #expect(value == TestStruct(value: 5, name: "five"))
            }

            arena.withValue(ref1) { value in
                #expect(value == 100)
            }

            arena.withValue(ref2) { value in
                #expect(value == "value")
            }
        }

        @Test("Async variadic access out of order")
        func asyncVariadicAccessOutOfOrder() async {
            let archetype = Arena.Archetype()
            archetype.addSlab(of: Double?.self)

            let ref1 = archetype.allocate(String?.self)
            let ref2 = archetype.allocate(Int?.self)
            let ref3 = archetype.allocate(Double?.self)
            let ref4 = archetype.allocate(Bool?.self)

            let arena = Arena(archetype)

            // Set values asynchronously
            await arena.withValue(ref1) { value in value = "async" }
            await arena.withValue(ref2) { value in value = 999 }
            await arena.withValue(ref3) { value in value = 2.71828 }
            await arena.withValue(ref4) { value in value = false }

            // Access out of order: 4, 1, 3, 2
            await arena.withValue(ref4) { value in
                #expect(value == false)
            }

            await arena.withValue(ref1) { value in
                #expect(value == "async")
            }

            await arena.withValue(ref3) { value in
                #expect(value == 2.71828)
            }

            await arena.withValue(ref2) { value in
                #expect(value == 999)
            }
        }

        @Test("Parameter pack with mixed copyable and noncopyable")
        func parameterPackMixedCopyability() {
            let onDeinit: @Sendable (Int) -> Void = { _ in }

            let archetype = Arena.Archetype()

            let copyableRef = archetype.allocate(Int?.self)
            let noncopyableRef = archetype.allocate(NoncopyableValue?.self)
            let classRef = archetype.allocate(DeinitTracker?.self)

            let arena = Arena(archetype)

            // Set copyable value via withValue
            arena.withValue(copyableRef) { $0 = 777 }

            // Set noncopyable value via withValue
            arena.withValue(noncopyableRef) { value in
                value = NoncopyableValue(id: 1, onDeinit: onDeinit)
            }

            // Set class via withValue
            arena.withValue(classRef) { $0 = DeinitTracker(id: 2, onDeinit: onDeinit) }

            // Access out of order: class, copyable, noncopyable
            #expect(arena[classRef]?.id == 2)
            #expect(arena[copyableRef] == 777)

            arena.withValue(noncopyableRef) { value in
                #expect(value?.id == 1)
            }
        }

        @Test("Large parameter pack across all slab types")
        func largeParameterPackAcrossSlabs() {
            let archetype = Arena.Archetype()

            // Add several typed slabs
            archetype.addSlab(of: String?.self)
            archetype.addSlab(of: Int?.self)
            archetype.addSlab(of: Bool?.self)

            // Create many references across different slabs
            let refs: [(any Any, Int)] = [
                (archetype.allocate(Int?.self), 1),        // TypedSlab
                (archetype.allocate(String?.self), 2),     // TypedSlab
                (archetype.allocate(Bool?.self), 3),       // TypedSlab
                (archetype.allocate(Double?.self), 4),     // BitwiseCopyableSlab
                (archetype.allocate(TestStruct?.self), 5), // HeterogenousSlab
                (archetype.allocate(Int?.self), 6),        // TypedSlab
                (archetype.allocate(String?.self), 7),     // TypedSlab
                (archetype.allocate(Float?.self), 8),      // BitwiseCopyableSlab
            ]

            let arena = Arena(archetype)

            // Access in specific type-safe manner
            let intRef1 = refs[0].0 as! Arena.Reference<Int?>
            let stringRef1 = refs[1].0 as! Arena.Reference<String?>
            let boolRef = refs[2].0 as! Arena.Reference<Bool?>
            let doubleRef = refs[3].0 as! Arena.Reference<Double?>
            let structRef = refs[4].0 as! Arena.Reference<TestStruct?>
            let intRef2 = refs[5].0 as! Arena.Reference<Int?>
            let stringRef2 = refs[6].0 as! Arena.Reference<String?>
            let floatRef = refs[7].0 as! Arena.Reference<Float?>

            // Set values
            arena.withValue(intRef1) { $0 = 10 }
            arena.withValue(stringRef1) { $0 = "first" }
            arena.withValue(boolRef) { $0 = true }
            arena.withValue(doubleRef) { $0 = 3.14 }
            arena.withValue(structRef) { $0 = TestStruct(value: 42, name: "answer") }
            arena.withValue(intRef2) { $0 = 20 }
            arena.withValue(stringRef2) { $0 = "second" }
            arena.withValue(floatRef) { $0 = 2.5 }

            // Access out of order: 8, 4, 1, 5, 2, 7, 3, 6
            #expect(arena[floatRef] == 2.5)
            #expect(arena[doubleRef] == 3.14)
            #expect(arena[intRef1] == 10)
            #expect(arena[structRef] == TestStruct(value: 42, name: "answer"))
            #expect(arena[stringRef1] == "first")
            #expect(arena[stringRef2] == "second")
            #expect(arena[boolRef] == true)
            #expect(arena[intRef2] == 20)
        }
    }
}
