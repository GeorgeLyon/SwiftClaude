import Foundation
import Testing

@testable import JSONSupport

@Suite("Object Tests")
private struct ObjectTests {

  @Test
  func emptyObjectTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{}  ")
      stream.finish()

      let result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.isComplete)

      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
    }

    /// With whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("{ } ")
      stream.finish()

      let result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func simpleObjectTest() async throws {
    /// Object with string values
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"name\": \"John\", \"city\": \"New York\"}")
      stream.finish()

      var properties: [(key: String, value: String)] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        // Decode value
        var valueState = try stream.decodeStringStart().getValue()
        var valueFragments: [String] = []
        try stream.decodeStringFragments(state: &valueState) { fragment in
          valueFragments.append(String(fragment))
        }
        properties.append((key: String(key), value: valueFragments.joined()))

        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.map { $0.key } == ["name", "city"])
      #expect(properties.map { $0.value } == ["John", "New York"])
    }
  }

  @Test
  func objectWithNumbersTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"age\": 30, \"height\": 175.5, \"score\": -42}")
      stream.finish()

      var properties: [(key: String, value: JSON.Number)] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        let number = try stream.decodeNumber().getValue()
        properties.append((key: String(key), value: number))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.map { $0.key } == ["age", "height", "score"])
      #expect(properties[0].value.integerPart == "30")
      #expect(properties[1].value.integerPart == "175")
      #expect(properties[1].value.fractionalPart == "5")
      #expect(properties[2].value.stringValue == "-42")
      #expect(properties[2].value.integerPart == "-42")
    }
  }

  @Test
  func objectWithBooleansTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"active\": true, \"verified\": false, \"admin\": true}")
      stream.finish()

      var properties: [(key: String, value: Bool)] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        let boolean = try stream.decodeBoolean().getValue()
        properties.append((key: String(key), value: boolean))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.map { $0.key } == ["active", "verified", "admin"])
      #expect(properties.map { $0.value } == [true, false, true])
    }
  }

  @Test
  func objectWithNullsTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"field1\": null, \"field2\": null, \"field3\": null}")
      stream.finish()

      var nullProperties: [String] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        _ = try stream.decodeNull().getValue()
        nullProperties.append(String(key))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(nullProperties == ["field1", "field2", "field3"])
    }
  }

  @Test
  func nestedObjectTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push(
        "{\"user\": {\"name\": \"Alice\", \"age\": 25}, \"location\": {\"city\": \"NYC\"}}")
      stream.finish()

      var properties: [(key: String, nestedProps: [(key: String, value: String)])] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        var nestedProps: [(key: String, value: String)] = []

        var nestedResult = try stream.decodeObjectUpToFirstPropertyValue()
        while let nestedKey = nestedResult.decodingPropertyName {
          if nestedKey == "age" {
            let number = try stream.decodeNumber().getValue()
            nestedProps.append((key: String(nestedKey), value: String(number.integerPart)))
          } else {
            var state = try stream.decodeStringStart().getValue()
            var fragments: [String] = []
            try stream.decodeStringFragments(state: &state) { fragment in
              fragments.append(String(fragment))
            }
            nestedProps.append((key: String(nestedKey), value: fragments.joined()))
          }
          nestedResult = try stream.decodeObjectUpToNextPropertyValue()
        }

        properties.append((key: String(key), nestedProps: nestedProps))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.count == 2)
      #expect(properties[0].key == "user")
      #expect(properties[0].nestedProps.map { $0.key } == ["name", "age"])
      #expect(properties[0].nestedProps.map { $0.value } == ["Alice", "25"])
      #expect(properties[1].key == "location")
      #expect(properties[1].nestedProps.map { $0.key } == ["city"])
      #expect(properties[1].nestedProps.map { $0.value } == ["NYC"])
    }
  }

  @Test
  func mixedTypeObjectTest() async throws {
    /// Object with different types of values
    do {
      var stream = JSON.DecodingStream()
      stream.push(
        "{\"count\": 42, \"name\": \"test\", \"active\": true, \"data\": null, \"price\": 19.99}")
      stream.finish()

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      // First property: number
      #expect(result.decodingPropertyName == "count")
      let number1 = try stream.decodeNumber().getValue()
      #expect(number1.integerPart == "42")

      result = try stream.decodeObjectUpToNextPropertyValue()

      // Second property: string
      #expect(result.decodingPropertyName == "name")
      var state = try stream.decodeStringStart().getValue()
      var fragments: [String] = []
      try stream.decodeStringFragments(state: &state) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "test")

      result = try stream.decodeObjectUpToNextPropertyValue()

      // Third property: boolean
      #expect(result.decodingPropertyName == "active")
      let boolean = try stream.decodeBoolean().getValue()
      #expect(boolean == true)

      result = try stream.decodeObjectUpToNextPropertyValue()

      // Fourth property: null
      #expect(result.decodingPropertyName == "data")
      _ = try stream.decodeNull().getValue()

      result = try stream.decodeObjectUpToNextPropertyValue()

      // Fifth property: decimal number
      #expect(result.decodingPropertyName == "price")
      let decimal = try stream.decodeNumber().getValue()
      #expect(decimal.integerPart == "19")
      #expect(decimal.fractionalPart == "99")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func whitespaceInObjectTest() async throws {
    /// Object with various whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("{ \"a\" : 1 , \"b\" : 2 }")
      stream.finish()

      var properties: [(key: String, value: Int)] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        let number = try stream.decodeNumber().getValue()
        properties.append((key: String(key), value: Int(number.integerPart)!))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.map { $0.key } == ["a", "b"])
      #expect(properties.map { $0.value } == [1, 2])
    }

    /// Object with newlines and tabs
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\n\t\"x\":\t10,\n\t\"y\":\t20\n}")
      stream.finish()

      var properties: [(key: String, value: Int)] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        let number = try stream.decodeNumber().getValue()
        properties.append((key: String(key), value: Int(number.integerPart)!))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.map { $0.key } == ["x", "y"])
      #expect(properties.map { $0.value } == [10, 20])
    }
  }

  @Test
  func incrementalObjectParsingTest() async throws {
    /// Parse object incrementally
    do {
      var stream = JSON.DecodingStream()
      stream.push("{")

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.needsMoreData)

      stream.push("\"ke")
      result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.needsMoreData)

      stream.push("y1\": 4")
      result = try stream.decodeObjectUpToFirstPropertyValue()

      #expect(result.decodingPropertyName == "key1")

      let needsMoreData = try stream.decodeNumber().needsMoreData
      #expect(needsMoreData)

      stream.push("2, ")
      let firstNumber = try stream.decodeNumber().getValue()
      #expect(firstNumber.integerPart == "42")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.needsMoreData)

      stream.push("\"key2\": \"val")
      result = try stream.decodeObjectUpToNextPropertyValue()

      #expect(result.decodingPropertyName == "key2")

      var state = try stream.decodeStringStart().getValue()
      var collectedFragments: [String] = []
      try stream.decodeStringFragments(state: &state) { fragment in
        collectedFragments.append(String(fragment))
      }
      #expect(!state.isComplete)  // String is not complete yet

      stream.push("ue\"}")
      stream.finish()

      try stream.decodeStringFragments(state: &state) { fragment in
        collectedFragments.append(String(fragment))
      }
      #expect(collectedFragments.joined() == "value")
      #expect(state.isComplete)

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func whitespaceBeforeOpeningBraceTest() async throws {
    /// Single space before opening brace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" {\"x\": 1, \"y\": 2}")
      stream.finish()

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "x")

      let first = try stream.decodeNumber().getValue()
      #expect(first.integerPart == "1")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.decodingPropertyName == "y")

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }

    /// Mixed whitespace before opening brace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n{\"value\": 42}")
      stream.finish()

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "value")

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func deeplyNestedObjectTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"a\": {\"b\": {\"c\": {\"d\": {\"e\": 5}}}}}")
      stream.finish()

      // Navigate through 5 levels of nesting
      var result = try stream.decodeObjectUpToFirstPropertyValue()
      for level in ["a", "b", "c", "d", "e"] {
        #expect(result.decodingPropertyName! == level)

        if level == "e" {
          // Get the value at the deepest level
          let number = try stream.decodeNumber().getValue()
          #expect(number.integerPart == "5")
        } else {
          // Continue navigating deeper
          result = try stream.decodeObjectUpToFirstPropertyValue()
        }
      }

      // Close all objects
      for _ in 0..<5 {
        result = try stream.decodeObjectUpToNextPropertyValue()
        #expect(result.isComplete)
      }
    }
  }

  @Test
  func objectWithArrayValuesTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"numbers\": [1, 2, 3], \"names\": [\"Alice\", \"Bob\"]}")
      stream.finish()

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      // First property: array of numbers
      #expect(result.decodingPropertyName == "numbers")

      var numbers: [Int] = []
      var arrayResult = try stream.decodeArrayUpToFirstElement()
      #expect(arrayResult == .decodingElement)

      while arrayResult == .decodingElement {
        let number = try stream.decodeNumber().getValue()
        numbers.append(Int(number.integerPart)!)
        arrayResult = try stream.decodeArrayUpToNextElement()
      }
      #expect(numbers == [1, 2, 3])

      result = try stream.decodeObjectUpToNextPropertyValue()

      // Second property: array of strings
      #expect(result.decodingPropertyName == "names")

      var names: [String] = []
      arrayResult = try stream.decodeArrayUpToFirstElement()
      #expect(arrayResult == .decodingElement)

      while arrayResult == .decodingElement {
        var state = try stream.decodeStringStart().getValue()
        var fragments: [String] = []
        try stream.decodeStringFragments(state: &state) { fragment in
          fragments.append(String(fragment))
        }
        names.append(fragments.joined())
        arrayResult = try stream.decodeArrayUpToNextElement()
      }
      #expect(names == ["Alice", "Bob"])

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func objectStreamingEdgeCasesTest() async throws {
    /// Empty object split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("{")

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.needsMoreData)

      stream.push("}")
      stream.finish()

      result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.isComplete)
    }

    /// Object with property name split
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"pro")

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.needsMoreData)

      stream.push("perty\": 42}")
      stream.finish()

      result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "property")

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }

    /// Colon split between property name and value
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"key\"")

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.needsMoreData)

      stream.push(": \"value\"}")
      stream.finish()

      result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "key")

      var state = try stream.decodeStringStart().getValue()
      var fragments: [String] = []
      try stream.decodeStringFragments(state: &state) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "value")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }

    /// Comma split between properties
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"a\": 1, ")

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "a")

      let first = try stream.decodeNumber().getValue()
      #expect(first.integerPart == "1")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.needsMoreData)

      stream.push(" \"b\": 2}")
      stream.finish()

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.decodingPropertyName == "b")

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }

    /// Whitespace around colons and commas
    do {
      var stream = JSON.DecodingStream()
      stream.push("{ \"a\" ")

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.needsMoreData)

      stream.push(" : ")
      result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(!result.needsMoreData)
      #expect(result.decodingPropertyName == "a")

      stream.push(" 1  ")
      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "1")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.needsMoreData)

      stream.push(" , \"b\" : 2 }")
      stream.finish()

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.decodingPropertyName == "b")

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func objectWithEscapedPropertyNamesTest() async throws {
    /// Property names with escape sequences
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"key\\\"with\\\"quotes\": 1, \"new\\nline\": 2, \"tab\\there\": 3}")
      stream.finish()

      var properties: [(key: String, value: Int)] = []

      var result = try stream.decodeObjectUpToFirstPropertyValue()

      while let key = result.decodingPropertyName {
        let number = try stream.decodeNumber().getValue()
        properties.append((key: String(key), value: Int(number.integerPart)!))
        result = try stream.decodeObjectUpToNextPropertyValue()
      }

      #expect(result.isComplete)
      #expect(properties.count == 3)
      #expect(properties[0].key == "key\"with\"quotes")  // Escapes are decoded
      #expect(properties[1].key == "new\nline")  // \n becomes newline
      #expect(properties[2].key == "tab\there")  // \t becomes tab
      #expect(properties.map { $0.value } == [1, 2, 3])
    }

    /// Unicode escapes in property names
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"\\u0048\\u0065\\u006C\\u006C\\u006F\": \"world\"}")
      stream.finish()

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "Hello")  // Unicode escapes are decoded to "Hello"

      var state = try stream.decodeStringStart().getValue()
      var fragments: [String] = []
      try stream.decodeStringFragments(state: &state) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "world")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)
    }
  }

  @Test
  func objectTrailingWhitespaceTest() async throws {
    /// Object with trailing whitespace after closing brace
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"x\": 1}  \n  ")
      stream.finish()

      var result = try stream.decodeObjectUpToFirstPropertyValue()
      #expect(result.decodingPropertyName == "x")

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "1")

      result = try stream.decodeObjectUpToNextPropertyValue()
      #expect(result.isComplete)

      // Verify we can read the trailing whitespace
      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
      #expect(try stream.readCharacter().decodingResult().getValue() == "\n")
    }
  }

}

// MARK: - Support

extension JSON.ObjectDecodingState {
  fileprivate var isComplete: Bool {
    if case .complete = self {
      return true
    } else {
      return false
    }
  }

  fileprivate var needsMoreData: Bool {
    if case .needsMoreData = self {
      return true
    } else {
      return false
    }
  }

  fileprivate var decodingPropertyName: Substring? {
    if case .decodingPropertyValue(let name) = self {
      return name
    } else {
      return nil
    }
  }
}
