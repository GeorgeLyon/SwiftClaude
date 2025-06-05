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

      var state = JSON.ArrayDecodingState()
      let result = try stream.decodeArrayComponent(&state)
      #expect(result.isArrayEnd)

      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
    }

    /// With whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("[ ]")
      stream.finish()

      var state = JSON.ArrayDecodingState()
      let result = try stream.decodeArrayComponent(&state)
      #expect(result.isArrayEnd)
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
      var state = JSON.ArrayDecodingState()

      while case .decoded(.elementStart) = try stream.decodeArrayComponent(&state) {
        let value = try stream.decodeNumber().getValue().decode(as: Int.self)
        elements.append(value)
      }

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

      var arrayState = JSON.ArrayDecodingState()
      while try stream.decodeArrayComponent(&arrayState).isElementStart {
        var state = JSON.StringDecodingState()
        var fragments: [String] = []
        _ = try stream.decodeStringFragments(state: &state) { fragment in
          fragments.append(String(fragment))
        }
        elements.append(fragments.joined())
      }

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
      var arrayState = JSON.ArrayDecodingState()
      while try stream.decodeArrayComponent(&arrayState).isElementStart {
        let boolean = try stream.decodeBoolean().getValue()
        elements.append(boolean)
      }

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
      var arrayState = JSON.ArrayDecodingState()
      while try stream.decodeArrayComponent(&arrayState).isElementStart {
        _ = try stream.decodeNull().getValue()
        nullCount += 1
      }

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
      var arrayState = JSON.ArrayDecodingState()
      while try stream.decodeArrayComponent(&arrayState).isElementStart {
        var innerArray: [Int] = []

        var arrayState = JSON.ArrayDecodingState()
        while try stream.decodeArrayComponent(&arrayState).isElementStart {
          let number = try stream.decodeNumber().getValue()
          let intValue = try number.decode(as: Int.self)
          innerArray.append(intValue)
        }

        arrays.append(innerArray)
      }

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

      var arrayState = JSON.ArrayDecodingState()
      var result = try stream.decodeArrayComponent(&arrayState)
      #expect(result.isElementStart)

      // First element: number
      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeArrayComponent(&arrayState)
      #expect(result.isElementStart)

      // Second element: string
      var state = JSON.StringDecodingState()
      var fragments: [String] = []
      _ = try stream.decodeStringFragments(state: &state) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "hello")

      result = try stream.decodeArrayComponent(&arrayState)
      #expect(result.isElementStart)

      // Third element: boolean
      let boolean = try stream.decodeBoolean().getValue()
      #expect(boolean == true)

      result = try stream.decodeArrayComponent(&arrayState)
      #expect(result.isElementStart)

      // Fourth element: null
      _ = try stream.decodeNull().getValue()

      result = try stream.decodeArrayComponent(&arrayState)
      #expect(result.isElementStart)

      // Fifth element: decimal number
      let decimal = try stream.decodeNumber().getValue()
      #expect(decimal.integerPart == "3")
      #expect(decimal.fractionalPart == "14")

      result = try stream.decodeArrayComponent(&arrayState)
      #expect(result.isArrayEnd)
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
      var arrayState = JSON.ArrayDecodingState()
      while try stream.decodeArrayComponent(&arrayState).isElementStart {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
      }

      #expect(elements == [1, 2, 3])
    }

    /// Array with newlines and tabs
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\n\t1,\n\t2,\n\t3\n]")
      stream.finish()

      var elements: [Int] = []
      var arrayState = JSON.ArrayDecodingState()
      while try stream.decodeArrayComponent(&arrayState).isElementStart {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
      }

      #expect(elements == [1, 2, 3])
    }
  }

  @Test
  func incrementalArrayParsingTest() async throws {
    /// Parse array incrementally
    do {
      var stream = JSON.DecodingStream()
      stream.push("[")

      var state = JSON.ArrayDecodingState()

      var result = try stream.decodeArrayComponent(&state)
      #expect(result.needsMoreData)

      stream.push("12")
      result = try stream.decodeArrayComponent(&state)
      #expect(result.isElementStart)

      let needsMoreData = try stream.decodeNumber().needsMoreData
      #expect(needsMoreData)

      stream.push(", ")

      let firstNumber = try stream.decodeNumber().getValue()
      #expect(firstNumber.integerPart == "12")

      result = try stream.decodeArrayComponent(&state)
      #expect(result.isElementStart)

      stream.push("2] ")

      let secondNumber = try stream.decodeNumber().getValue()
      #expect(secondNumber.integerPart == "2")

      result = try stream.decodeArrayComponent(&state)
      #expect(result.isArrayEnd)
    }

    /// Incremental parsing with strings
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\"hel")

      var state = JSON.ArrayDecodingState()
      let result = try stream.decodeArrayComponent(&state)
      #expect(result.isElementStart)

      do {
        var stringState = JSON.StringDecodingState()
        try stream.withDecodedStringFragments(state: &stringState) { fragments in
          #expect(fragments == ["he"])
        }

        stream.push("lo\"]")
        stream.finish()

        try stream.withDecodedStringFragments(state: &stringState) { fragments in
          #expect(fragments == ["llo"])
        }

        let result = try stream.decodeArrayComponent(&state)
        #expect(result.isArrayEnd)
      }
    }
  }

  @Test
  func trailingCommaTest() async throws {
    /// Array with trailing comma should still complete properly
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, 2, 3, ")

      var elements: [Int] = []
      var state = JSON.ArrayDecodingState()
      var result = try stream.decodeArrayComponent(&state)
      #expect(result.isElementStart)

      // Parse first three elements
      for _ in 0..<3 {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        elements.append(intValue)
        result = try stream.decodeArrayComponent(&state)
        #expect(result.isElementStart)
      }

      // Now we're after the trailing comma, waiting for next element or ]
      result = try stream.decodeArrayComponent(&state)
      #expect(result.needsMoreData)

      stream.push("]")
      stream.finish()

      // Should complete after the closing bracket
      result = try stream.decodeArrayComponent(&state)
      #expect(result.isArrayEnd)

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

      var state = JSON.ArrayDecodingState()
      var result = try stream.decodeArrayComponent(&state)
      #expect(result.isElementStart)

      let first = try stream.decodeNumber().getValue()
      #expect(first.integerPart == "1")

      result = try stream.decodeArrayComponent(&state)

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeArrayComponent(&state)
      #expect(result.isArrayEnd)
    }

    /// Mixed whitespace before opening bracket
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n[42]")
      stream.finish()

      var state = JSON.ArrayDecodingState()
      var result = try stream.decodeArrayComponent(&state)
      #expect(result.isElementStart)

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeArrayComponent(&state)

      #expect(result.isArrayEnd)
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
        let result = try stream.readArrayUpToFirstElement().decodingResult()
        #expect(result.isElementStart)
      }

      // Get the value
      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "5")

      // Close all arrays
      for _ in 0..<5 {
        let result = try stream.readArrayUpToNextElement().decodingResult()
        #expect(result.isArrayEnd)
      }
    }
  }
}

extension JSON.DecodingResult where Value == JSON.ArrayComponent {

  var isElementStart: Bool {
    if case .decoded(.elementStart) = self {
      return true
    } else {
      return false
    }
  }

  var isArrayEnd: Bool {
    if case .decoded(.end) = self {
      return true
    } else {
      return false
    }
  }

}
