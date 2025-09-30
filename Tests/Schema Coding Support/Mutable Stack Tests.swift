import Testing

@testable import SchemaCodingSupport

@Suite("Mutable Stack")
struct MutableStackTests {

  @Test
  func basicPushPop() {
    var stack = MutableStack()

    let ref = stack.push(42)
    let value = stack.pop(ref)

    #expect(value == 42)
  }

  @Test
  func multiplePushPop() {
    var stack = MutableStack()

    let ref1 = stack.push(10)
    let ref2 = stack.push(20)
    let ref3 = stack.push(30)

    let val3 = stack.pop(ref3)
    let val2 = stack.pop(ref2)
    let val1 = stack.pop(ref1)

    #expect(val3 == 30)
    #expect(val2 == 20)
    #expect(val1 == 10)
  }

  @Test
  func mixedTypes() {
    var stack = MutableStack()

    let intRef = stack.push(42)
    let stringRef = stack.push("Hello")
    let doubleRef = stack.push(3.14)

    let doubleVal = stack.pop(doubleRef)
    let stringVal = stack.pop(stringRef)
    let intVal = stack.pop(intRef)

    #expect(doubleVal == 3.14)
    #expect(stringVal == "Hello")
    #expect(intVal == 42)
  }

  @Test
  func withValueSync() {
    var stack = MutableStack()

    let ref = stack.push(100)

    let result = stack.withValue(for: ref) { value in
      value += 50
      return value * 2
    }

    #expect(result == 300)

    let finalValue = stack.pop(ref)
    #expect(finalValue == 150)
  }

  @Test
  func withValueAsync() async {
    var stack = MutableStack()

    let ref = stack.push("Hello")

    let result = await stack.withValue(for: ref) { value in
      value += " World"
      return value.count
    }

    #expect(result == 11)

    let finalValue = stack.pop(ref)
    #expect(finalValue == "Hello World")
  }

  @Test
  func multipleWithValueCalls() {
    var stack = MutableStack()

    let ref = stack.push(10)

    stack.withValue(for: ref) { value in
      value += 5
    }

    stack.withValue(for: ref) { value in
      value *= 2
    }

    stack.withValue(for: ref) { value in
      value -= 3
    }

    let finalValue = stack.pop(ref)
    #expect(finalValue == 27)  // ((10 + 5) * 2) - 3
  }

  @Test
  func largeValues() {
    struct LargeStruct {
      let data: [Int]

      init(size: Int) {
        self.data = Array(0..<size)
      }
    }

    var stack = MutableStack()

    let ref = stack.push(LargeStruct(size: 1000))

    stack.withValue(for: ref) { value in
      #expect(value.data.count == 1000)
      #expect(value.data[500] == 500)
    }

    let popped = stack.pop(ref)
    #expect(popped.data.count == 1000)
  }

  @Test
  func multipleBlocks() {
    var stack = MutableStack()
    var references: [MutableStack.Reference<[UInt8]>] = []

    // Push many large values to force multiple blocks
    for i in 0..<10 {
      let data = Array(repeating: UInt8(i), count: 1024)
      references.append(stack.push(data))
    }

    // Pop them all in reverse order
    for i in (0..<10).reversed() {
      let value = stack.pop(references[i])
      #expect(value.count == 1024)
      #expect(value[0] == UInt8(i))
    }
  }

  @Test
  func stringValues() {
    var stack = MutableStack()

    let ref1 = stack.push("First")
    let ref2 = stack.push("Second")
    let ref3 = stack.push("Third")

    stack.withValue(for: ref2) { value in
      value += " (modified)"
    }

    #expect(stack.pop(ref3) == "Third")
    #expect(stack.pop(ref2) == "Second (modified)")
    #expect(stack.pop(ref1) == "First")
  }

  @Test
  func optionalValues() {
    var stack = MutableStack()

    let ref1 = stack.push(Optional<Int>.some(42))
    let ref2 = stack.push(Optional<Int>.none)

    let val2 = stack.pop(ref2)
    let val1 = stack.pop(ref1)

    #expect(val2 == nil)
    #expect(val1 == 42)
  }

  @Test
  func arrayValues() {
    var stack = MutableStack()

    let ref = stack.push([1, 2, 3, 4, 5])

    stack.withValue(for: ref) { value in
      value.append(6)
      value.append(7)
    }

    let result = stack.pop(ref)
    #expect(result == [1, 2, 3, 4, 5, 6, 7])
  }

  @Test
  func dictionaryValues() {
    var stack = MutableStack()

    let ref = stack.push(["a": 1, "b": 2])

    stack.withValue(for: ref) { value in
      value["c"] = 3
    }

    let result = stack.pop(ref)
    #expect(result == ["a": 1, "b": 2, "c": 3])
  }

  @Test
  func nestedAccess() {
    var stack = MutableStack()

    struct Person {
      var name: String
      var age: Int
    }

    let ref = stack.push(Person(name: "Alice", age: 30))

    stack.withValue(for: ref) { person in
      person.age += 1
      person.name = "Alice Smith"
    }

    let result = stack.pop(ref)
    #expect(result.name == "Alice Smith")
    #expect(result.age == 31)
  }

  @Test
  func manySmallValues() {
    var stack = MutableStack()
    var refs: [MutableStack.Reference<Int>] = []

    // Push 100 small values
    for i in 0..<100 {
      refs.append(stack.push(i))
    }

    // Pop them all in reverse order
    for i in (0..<100).reversed() {
      let value = stack.pop(refs[i])
      #expect(value == i)
    }
  }

  @Test
  func withValueThrows() {
    enum TestError: Error {
      case intentional
    }

    var stack = MutableStack()
    let ref = stack.push(42)

    do {
      let _ = try stack.withValue(for: ref) { value -> Int in
        value += 10
        throw TestError.intentional
      }
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error is TestError)
    }

    // Value should still be modified before throw
    let result = stack.pop(ref)
    #expect(result == 52)
  }

  @Test
  func withValueAsyncThrows() async {
    enum TestError: Error {
      case intentional
    }

    var stack = MutableStack()
    let ref = stack.push("test")

    do {
      let _ = try await stack.withValue(for: ref) { value -> String in
        value += " modified"
        throw TestError.intentional
      }
      Issue.record("Expected error to be thrown")
    } catch {
      #expect(error is TestError)
    }

    let result = stack.pop(ref)
    #expect(result == "test modified")
  }

  @Test
  func complexStructValue() {
    struct ComplexData {
      var numbers: [Int]
      var strings: [String]
      var nested: [String: [Int]]

      static var sample: ComplexData {
        ComplexData(
          numbers: [1, 2, 3],
          strings: ["a", "b", "c"],
          nested: ["x": [10, 20], "y": [30, 40]]
        )
      }
    }

    var stack = MutableStack()
    let ref = stack.push(ComplexData.sample)

    stack.withValue(for: ref) { value in
      value.numbers.append(4)
      value.strings.append("d")
      value.nested["z"] = [50, 60]
    }

    let result = stack.pop(ref)
    #expect(result.numbers == [1, 2, 3, 4])
    #expect(result.strings == ["a", "b", "c", "d"])
    #expect(result.nested["z"] == [50, 60])
  }

  @Test
  func booleanValues() {
    var stack = MutableStack()

    let ref1 = stack.push(true)
    let ref2 = stack.push(false)

    stack.withValue(for: ref1) { value in
      value.toggle()
    }

    #expect(stack.pop(ref2) == false)
    #expect(stack.pop(ref1) == false)
  }

  @Test
  func tupleValues() {
    var stack = MutableStack()

    let ref = stack.push((42, "Hello", 3.14))

    let result = stack.pop(ref)
    #expect(result.0 == 42)
    #expect(result.1 == "Hello")
    #expect(result.2 == 3.14)
  }

  @Test
  func emptyCollections() {
    var stack = MutableStack()

    let arrayRef = stack.push([Int]())
    let dictRef = stack.push([String: Int]())
    let stringRef = stack.push("")

    #expect(stack.pop(stringRef) == "")
    #expect(stack.pop(dictRef).isEmpty)
    #expect(stack.pop(arrayRef).isEmpty)
  }

  @Test
  func interleaved() {
    var stack = MutableStack()

    let ref1 = stack.push(10)
    let ref2 = stack.push(20)

    stack.withValue(for: ref1) { $0 += 5 }

    let ref3 = stack.push(30)

    stack.withValue(for: ref2) { $0 += 5 }

    #expect(stack.pop(ref3) == 30)
    #expect(stack.pop(ref2) == 25)
    #expect(stack.pop(ref1) == 15)
  }

}
