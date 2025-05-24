import Foundation
import Testing

@testable import JSONSupport

@Suite("Array Tests")
private struct ArrayTests {

  @Test
  func emptyArrayTest() async throws {
    /// Complete empty array
    do {
      var value = JSON.Value()
      value.stream.push("[]")
      value.stream.finish()

      var decoder = value.decodeArray()
      let firstElement: String? = try decoder.decodeNextElement { stream in
        return "element"
      }
      #expect(firstElement == nil)
      #expect(decoder.isComplete == true)
    }

    /// Empty array with whitespace
    do {
      var value = JSON.Value()
      value.stream.push("[ \t\n ]")
      value.stream.finish()

      var decoder = value.decodeArray()
      let firstElement: String? = try decoder.decodeNextElement { stream in
        return "element"
      }
      #expect(firstElement == nil)
      #expect(decoder.isComplete == true)
    }

    /// Leading whitespace
    do {
      var value = JSON.Value()
      value.stream.push("  []")
      value.stream.finish()

      var decoder = value.decodeArray()
      let firstElement: String? = try decoder.decodeNextElement { stream in
        return "element"
      }
      #expect(firstElement == nil)
      #expect(decoder.isComplete == true)
    }
  }

  @Test
  func finishTest() async throws {
    /// Test finish method
    do {
      var value = JSON.Value()
      value.stream.push("[]")
      value.stream.finish()

      let decoder = value.decodeArray()
      var remainingStream = try decoder.finish()
      #expect(remainingStream.readCharacter() == nil)
    }

    /// Test finish with trailing content
    do {
      var value = JSON.Value()
      value.stream.push("[], \"next\"")
      value.stream.finish()

      let decoder = value.decodeArray()
      var remainingStream = try decoder.finish()
      #expect(remainingStream.readCharacter() == ",")
    }
  }

  @Test
  func basicArrayElementTest() async throws {
    /// Test reading simple elements without complex nested decoders
    do {
      var value = JSON.Value()
      value.stream.push("[42, 43, 44]")
      value.stream.finish()

      var decoder = value.decodeArray()

      // Read first element
      let firstElement: String? = try decoder.decodeNextElement { stream in
        stream.readWhitespace()
        var number = ""
        while let char = stream.readCharacter(), char.isNumber {
          number.append(char)
        }
        return number.isEmpty ? nil : number
      }
      #expect(firstElement == "42")

      // Read second element
      let secondElement: String? = try decoder.decodeNextElement { stream in
        stream.readWhitespace()
        var number = ""
        while let char = stream.readCharacter(), char.isNumber {
          number.append(char)
        }
        return number.isEmpty ? nil : number
      }
      #expect(secondElement == "43")

      // Read third element
      let thirdElement: String? = try decoder.decodeNextElement { stream in
        stream.readWhitespace()
        var number = ""
        while let char = stream.readCharacter(), char.isNumber {
          number.append(char)
        }
        return number.isEmpty ? nil : number
      }
      #expect(thirdElement == "44")

      // No more elements
      let fourthElement: String? = try decoder.decodeNextElement { stream in
        return "element"
      }
      #expect(fourthElement == nil)
      #expect(decoder.isComplete == true)
    }
  }

  @Test
  func invalidArrayTest() async throws {
    /// Missing opening bracket
    do {
      var value = JSON.Value()
      value.stream.push("1, 2, 3]")
      value.stream.finish()

      var decoder = value.decodeArray()
      let element: String? = try decoder.decodeNextElement { stream in
        return "element"
      }
      #expect(element == nil)
    }

    /// Missing closing bracket
    do {
      var value = JSON.Value()
      value.stream.push("[1, 2, 3")
      value.stream.finish()

      var decoder = value.decodeArray()

      // Should be able to read elements
      let first: String? = try decoder.decodeNextElement { stream in
        stream.readWhitespace()
        var number = ""
        while let char = stream.readCharacter(), char.isNumber {
          number.append(char)
        }
        return number.isEmpty ? nil : number
      }
      #expect(first == "1")

      let second: String? = try decoder.decodeNextElement { stream in
        stream.readWhitespace()
        var number = ""
        while let char = stream.readCharacter(), char.isNumber {
          number.append(char)
        }
        return number.isEmpty ? nil : number
      }
      #expect(second == "2")

      let third: String? = try decoder.decodeNextElement { stream in
        stream.readWhitespace()
        var number = ""
        while let char = stream.readCharacter(), char.isNumber {
          number.append(char)
        }
        return number.isEmpty ? nil : number
      }
      #expect(third == "3")

      do {
        _ = try decoder.finish()
        #expect(false)
      } catch {
        /// We expect an error to be thrown because the array is incomplete
      }
    }
  }

  @Test
  func arrayWithWhitespaceTest() async throws {
    /// Various whitespace patterns
    do {
      var value = JSON.Value()
      value.stream.push("[ 1 , 2 , 3 ]")
      value.stream.finish()

      var decoder = value.decodeArray()
      var elements: [String] = []

      while true {
        let element: String? = try decoder.decodeNextElement({ stream in
          stream.readWhitespace()
          var number = ""
          while let char = stream.readCharacter(), char.isNumber {
            number.append(char)
          }
          return number.isEmpty ? nil : number
        })

        guard let element = element else { break }
        elements.append(element)
      }

      #expect(elements == ["1", "2", "3"])
      #expect(decoder.isComplete == true)
    }
  }
}
