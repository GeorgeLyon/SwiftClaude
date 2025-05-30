import Foundation
import Testing

@testable import JSONSupport

@Suite("Array Tests")
private struct ArrayTests {

  @Test
  func emptyArrayTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("[]  ")
      stream.finish()

      let result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .complete)

      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
    }

    /// With whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("[ ]")
      stream.finish()

      let result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .complete)
    }
  }

  @Test
  func simpleArrayTest() async throws {
    /// Array of numbers
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, 2, 3]")
      stream.finish()

      var elements: [Int] = []

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      while result == .decodingElement {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
        result = try stream.decodeArrayUpToNextElement()
      }

      #expect(result == .complete)
      #expect(elements == [1, 2, 3])
    }
  }

  @Test
  func arrayOfStringsTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\"hello\", \"world\", \"!\"]")
      stream.finish()

      var elements: [String] = []

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      while result == .decodingElement {
        var state = try stream.decodeStringStart().getValue()
        var fragments: [String] = []
        try stream.decodeStringFragments(state: &state) { fragment in
          fragments.append(String(fragment))
        }
        elements.append(fragments.joined())
        result = try stream.decodeArrayUpToNextElement()
      }

      #expect(result == .complete)
      #expect(elements == ["hello", "world", "!"])
    }
  }

  @Test
  func arrayOfBooleansTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("[true, false, true]")
      stream.finish()

      var elements: [Bool] = []

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      while result == .decodingElement {
        let boolean = try stream.decodeBoolean().getValue()
        elements.append(boolean)
        result = try stream.decodeArrayUpToNextElement()
      }

      #expect(result == .complete)
      #expect(elements == [true, false, true])
    }
  }

  @Test
  func arrayWithNullsTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("[null, null, null]")
      stream.finish()

      var nullCount = 0

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      while result == .decodingElement {
        _ = try stream.decodeNull().getValue()
        nullCount += 1
        result = try stream.decodeArrayUpToNextElement()
      }

      #expect(result == .complete)
      #expect(nullCount == 3)
    }
  }

  @Test
  func nestedArrayTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("[[1, 2], [3, 4], [5]]")
      stream.finish()

      var arrays: [[Int]] = []

      var outerResult = try stream.decodeArrayUpToFirstElement()
      #expect(outerResult == .decodingElement)

      while outerResult == .decodingElement {
        var innerArray: [Int] = []

        var innerResult = try stream.decodeArrayUpToFirstElement()
        #expect(innerResult == .decodingElement)

        while innerResult == .decodingElement {
          let number = try stream.decodeNumber().getValue()
          let intValue = try number.decode(as: Int.self)
          innerArray.append(intValue)
          innerResult = try stream.decodeArrayUpToNextElement()
        }

        arrays.append(innerArray)
        outerResult = try stream.decodeArrayUpToNextElement()
      }

      #expect(outerResult == .complete)
      #expect(arrays == [[1, 2], [3, 4], [5]])
    }
  }

  @Test
  func mixedTypeArrayTest() async throws {
    /// Array with different types of elements
    do {
      var stream = JSON.DecodingStream()
      stream.push("[42, \"hello\", true, null, 3.14]")
      stream.finish()

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      // First element: number
      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .decodingElement)

      // Second element: string
      var state = try stream.decodeStringStart().getValue()
      var fragments: [String] = []
      try stream.decodeStringFragments(state: &state) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "hello")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .decodingElement)

      // Third element: boolean
      let boolean = try stream.decodeBoolean().getValue()
      #expect(boolean == true)

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .decodingElement)

      // Fourth element: null
      _ = try stream.decodeNull().getValue()

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .decodingElement)

      // Fifth element: decimal number
      let decimal = try stream.decodeNumber().getValue()
      #expect(decimal.integerPart == "3")
      #expect(decimal.fractionalPart == "14")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .complete)
    }
  }

  @Test
  func whitespaceInArrayTest() async throws {
    /// Array with various whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("[ 1 , 2 , 3 ]")
      stream.finish()

      var elements: [Int] = []

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      while result == .decodingElement {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
        result = try stream.decodeArrayUpToNextElement()
      }

      #expect(result == .complete)
      #expect(elements == [1, 2, 3])
    }

    /// Array with newlines and tabs
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\n\t1,\n\t2,\n\t3\n]")
      stream.finish()

      var elements: [Int] = []

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      while result == .decodingElement {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
        result = try stream.decodeArrayUpToNextElement()
      }

      #expect(result == .complete)
      #expect(elements == [1, 2, 3])
    }
  }

  @Test
  func incrementalArrayParsingTest() async throws {
    /// Parse array incrementally
    do {
      var stream = JSON.DecodingStream()
      stream.push("[")

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .needsMoreData)

      stream.push("12")
      result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      let needsMoreData = try stream.decodeNumber().needsMoreData
      #expect(needsMoreData)

      stream.push(", ")

      let firstNumber = try stream.decodeNumber().getValue()
      #expect(firstNumber.integerPart == "12")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .decodingElement)

      stream.push("2] ")

      let secondNumber = try stream.decodeNumber().getValue()
      #expect(secondNumber.integerPart == "2")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .complete)
    }

    /// Incremental parsing with strings
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\"hel")

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) { fragments in
        #expect(fragments == ["he"])
      }

      stream.push("lo\"]")
      stream.finish()

      try stream.withDecodedStringFragments(state: &state) { fragments in
        #expect(fragments == ["llo"])
      }
      #expect(state.isComplete)

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .complete)
    }
  }

  @Test
  func trailingCommaTest() async throws {
    /// Array with trailing comma should still complete properly
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, 2, 3, ")

      var elements: [Int] = []
      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      // Parse first three elements
      for _ in 0..<3 {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
        result = try stream.decodeArrayUpToNextElement()
        #expect(result == .decodingElement)
      }

      // Now we're after the trailing comma, waiting for next element or ]
      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .needsMoreData)

      stream.push("]")
      stream.finish()

      // Should complete after the closing bracket
      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .complete)

      #expect(elements == [1, 2, 3])
    }
  }

  @Test
  func whitespaceBeforeOpeningBracketTest() async throws {
    /// Single space before opening bracket
    do {
      var stream = JSON.DecodingStream()
      stream.push(" [1, 2]")
      stream.finish()

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      let first = try stream.decodeNumber().getValue()
      #expect(first.integerPart == "1")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .decodingElement)

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .complete)
    }

    /// Mixed whitespace before opening bracket
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n[42]")
      stream.finish()

      var result = try stream.decodeArrayUpToFirstElement()
      #expect(result == .decodingElement)

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeArrayUpToNextElement()
      #expect(result == .complete)
    }
  }

  @Test
  func deeplyNestedArrayTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("[[[[[5]]]]]")
      stream.finish()

      // Navigate through 5 levels of nesting
      for _ in 0..<5 {
        let result = try stream.decodeArrayUpToFirstElement()
        #expect(result == .decodingElement)
      }

      // Get the value
      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "5")

      // Close all arrays
      for _ in 0..<5 {
        let result = try stream.decodeArrayUpToNextElement()
        #expect(result == .complete)
      }
    }
  }

}
