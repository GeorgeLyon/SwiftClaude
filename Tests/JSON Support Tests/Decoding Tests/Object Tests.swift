import Foundation
import Testing

@testable import JSONSupport

@Suite("Object")
struct ObjectTests {
  @Test
  func emptyObjectTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("{}  ")
      stream.finish()

      var state = JSON.ObjectDecodingState()
      let result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)

      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
    }

    /// With whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("{ } ")
      stream.finish()

      var state = JSON.ObjectDecodingState()
      let result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        // Decode value
        var valueState = JSON.StringDecodingState()
        var valueFragments: [String] = []
        _ = try stream.decodeStringFragments(state: &valueState) { fragment in
          valueFragments.append(String(fragment))
        }
        properties.append((key: String(name), value: valueFragments.joined()))

        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        let number = try stream.decodeNumber().getValue()
        properties.append((key: String(name), value: number))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        let boolean = try stream.decodeBoolean().getValue()
        properties.append((key: String(name), value: boolean))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        _ = try stream.decodeNull().getValue()
        nullProperties.append(String(name))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        var nestedProps: [(key: String, value: String)] = []

        var nestedState = JSON.ObjectDecodingState()
        var nestedResult = try stream.decodeObjectComponent(&nestedState)
        while case .decoded(.propertyValueStart(let nestedName)) = nestedResult {
          if nestedName == "age" {
            let number = try stream.decodeNumber().getValue()
            nestedProps.append((key: String(nestedName), value: String(number.integerPart)))
          } else {
            var stringState = JSON.StringDecodingState()
            var fragments: [String] = []
            _ = try stream.decodeStringFragments(state: &stringState) { fragment in
              fragments.append(String(fragment))
            }
            nestedProps.append((key: String(nestedName), value: fragments.joined()))
          }
          nestedResult = try stream.decodeObjectComponent(&nestedState)
        }

        properties.append((key: String(name), nestedProps: nestedProps))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      // First property: number
      #expect(result.propertyName == "count")
      let number1 = try stream.decodeNumber().getValue()
      #expect(number1.integerPart == "42")

      result = try stream.decodeObjectComponent(&state)

      // Second property: string
      #expect(result.propertyName == "name")
      var stringState = JSON.StringDecodingState()
      var fragments: [String] = []
      _ = try stream.decodeStringFragments(state: &stringState) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "test")

      result = try stream.decodeObjectComponent(&state)

      // Third property: boolean
      #expect(result.propertyName == "active")
      let boolean = try stream.decodeBoolean().getValue()
      #expect(boolean == true)

      result = try stream.decodeObjectComponent(&state)

      // Fourth property: null
      #expect(result.propertyName == "data")
      _ = try stream.decodeNull().getValue()

      result = try stream.decodeObjectComponent(&state)

      // Fifth property: decimal number
      #expect(result.propertyName == "price")
      let decimal = try stream.decodeNumber().getValue()
      #expect(decimal.integerPart == "19")
      #expect(decimal.fractionalPart == "99")

      result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        properties.append((key: String(name), value: intValue))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        properties.append((key: String(name), value: intValue))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push("\"ke")
      result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push("y1\": 4")
      result = try stream.decodeObjectComponent(&state)

      #expect(result.propertyName == "key1")

      let needsMoreData = try stream.decodeNumber().needsMoreData
      #expect(needsMoreData)

      stream.push("2, ")
      let firstNumber = try stream.decodeNumber().getValue()
      #expect(firstNumber.integerPart == "42")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push("\"key2\": \"val")
      result = try stream.decodeObjectComponent(&state)

      #expect(result.propertyName == "key2")

      var stringState = JSON.StringDecodingState()
      var collectedFragments: [String] = []
      var stringResult = try stream.decodeStringFragments(state: &stringState) { fragment in
        collectedFragments.append(String(fragment))
      }
      #expect(!stringResult.isComplete)  // String is not complete yet

      stream.push("ue\"}")
      stream.finish()

      stringResult = try stream.decodeStringFragments(state: &stringState) { fragment in
        collectedFragments.append(String(fragment))
      }
      #expect(collectedFragments.joined() == "value")
      #expect(stringResult.isComplete)

      result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "x")

      let first = try stream.decodeNumber().getValue()
      #expect(first.integerPart == "1")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "y")

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)
    }

    /// Mixed whitespace before opening brace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n{\"value\": 42}")
      stream.finish()

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "value")

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeObjectComponent(&state)
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
      var states: [JSON.ObjectDecodingState] = []

      for level in ["a", "b", "c", "d", "e"] {
        let state = JSON.ObjectDecodingState()
        states.append(state)
        let result = try stream.decodeObjectComponent(&states[states.count - 1])
        #expect(result.propertyName! == level)

        if level == "e" {
          // Get the value at the deepest level
          let number = try stream.decodeNumber().getValue()
          #expect(number.integerPart == "5")
        }
      }

      // Close all objects
      for i in (0..<5).reversed() {
        let result = try stream.decodeObjectComponent(&states[i])
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      // First property: array of numbers
      #expect(result.propertyName == "numbers")

      var numbers: [Int] = []
      var arrayState = JSON.ArrayDecodingState()

      while case .decoded(.elementStart) = try stream.decodeArrayComponent(&arrayState) {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        numbers.append(intValue)
      }
      #expect(numbers == [1, 2, 3])

      result = try stream.decodeObjectComponent(&state)

      // Second property: array of strings
      #expect(result.propertyName == "names")

      var names: [String] = []
      var arrayState2 = JSON.ArrayDecodingState()

      while case .decoded(.elementStart) = try stream.decodeArrayComponent(&arrayState2) {
        var stringState = JSON.StringDecodingState()
        var fragments: [String] = []
        _ = try stream.decodeStringFragments(state: &stringState) { fragment in
          fragments.append(String(fragment))
        }
        names.append(fragments.joined())
      }
      #expect(names == ["Alice", "Bob"])

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)
    }
  }

  @Test
  func objectStreamingEdgeCasesTest() async throws {
    /// Empty object split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("{")

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push("}")
      stream.finish()

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)
    }

    /// Object with property name split
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"pro")

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push("perty\": 42}")
      stream.finish()

      result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "property")

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "42")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)
    }

    /// Colon split between property name and value
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"key\"")

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push(": \"value\"}")
      stream.finish()

      result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "key")

      var stringState = JSON.StringDecodingState()
      var fragments: [String] = []
      _ = try stream.decodeStringFragments(state: &stringState) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "value")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)
    }

    /// Comma split between properties
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"a\": 1, ")

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "a")

      let first = try stream.decodeNumber().getValue()
      #expect(first.integerPart == "1")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push(" \"b\": 2}")
      stream.finish()

      result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "b")

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)
    }

    /// Whitespace around colons and commas
    do {
      var stream = JSON.DecodingStream()
      stream.push("{ \"a\" ")

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push(" : ")
      result = try stream.decodeObjectComponent(&state)
      #expect(!result.needsMoreData)
      #expect(result.propertyName == "a")

      stream.push(" 1  ")
      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "1")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.needsMoreData)

      stream.push(" , \"b\" : 2 }")
      stream.finish()

      result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "b")

      let second = try stream.decodeNumber().getValue()
      #expect(second.integerPart == "2")

      result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)

      while case .decoded(.propertyValueStart(let name)) = result {
        let number = try stream.decodeNumber().getValue()
        let intValue = try number.decode(as: Int.self)
        properties.append((key: String(name), value: intValue))
        result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "Hello")  // Unicode escapes are decoded to "Hello"

      var stringState = JSON.StringDecodingState()
      var fragments: [String] = []
      _ = try stream.decodeStringFragments(state: &stringState) { fragment in
        fragments.append(String(fragment))
      }
      #expect(fragments.joined() == "world")

      result = try stream.decodeObjectComponent(&state)
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

      var state = JSON.ObjectDecodingState()
      var result = try stream.decodeObjectComponent(&state)
      #expect(result.propertyName == "x")

      let number = try stream.decodeNumber().getValue()
      #expect(number.integerPart == "1")

      result = try stream.decodeObjectComponent(&state)
      #expect(result.isComplete)

      // Verify we can read the trailing whitespace
      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
      #expect(try stream.readCharacter().decodingResult().getValue() == " ")
      #expect(try stream.readCharacter().decodingResult().getValue() == "\n")
    }
  }
}

// MARK: - Support

extension JSON.DecodingResult where Value == JSON.ObjectComponent {

  fileprivate var propertyName: Substring? {
    if case .decoded(.propertyValueStart(let name)) = self {
      return name
    } else {
      return nil
    }
  }

  fileprivate var isComplete: Bool {
    if case .decoded(.end) = self {
      return true
    } else {
      return false
    }
  }

}
