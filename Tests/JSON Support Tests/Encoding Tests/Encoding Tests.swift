import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct EncodingTests {

  // MARK: - Primitive Encoding Tests

  @Test
  func testNullEncoding() {
    var stream = JSON.EncodingStream()
    stream.encodeNull()
    #expect(stream.string == "null")
  }

  @Test
  func testBooleanEncoding() {
    var stream = JSON.EncodingStream()

    // True
    stream.encode(true)
    #expect(stream.string == "true")

    // Reset and test false
    stream.reset()
    stream.encode(false)
    #expect(stream.string == "false")
  }

  @Test
  func testIntegerEncoding() {
    var stream = JSON.EncodingStream()

    // Zero
    stream.encode(0)
    #expect(stream.string == "0")

    // Positive integer
    stream.reset()
    stream.encode(42)
    #expect(stream.string == "42")

    // Negative integer
    stream.reset()
    stream.encode(-123)
    #expect(stream.string == "-123")

    // Large integer
    stream.reset()
    stream.encode(Int64.max)
    #expect(stream.string == "9223372036854775807")
  }

  @Test
  func testFloatingPointEncoding() {
    var stream = JSON.EncodingStream()

    // Zero
    stream.encode(0.0)
    #expect(stream.string == "0")

    // Positive float
    stream.reset()
    stream.encode(3.14159)
    #expect(stream.string == "3.14159")

    // Negative float
    stream.reset()
    stream.encode(-2.718)
    #expect(stream.string == "-2.718")

    // Scientific notation (may be platform-dependent)
    stream.reset()
    stream.encode(1.23e-5)
    let scientificResult = stream.string
    #expect(scientificResult.contains("e") || scientificResult.contains("E"))
  }

  @Test
  func testStringEncoding() {
    var stream = JSON.EncodingStream()

    // Empty string
    stream.encode("")
    #expect(stream.string == "\"\"")

    // Basic string
    stream.reset()
    stream.encode("Hello, World!")
    #expect(stream.string == "\"Hello, World!\"")

    // String with quotes
    stream.reset()
    stream.encode("She said, \"Hello!\"")
    #expect(stream.string == "\"She said, \\\"Hello!\\\"\"")

    // String with escape characters
    stream.reset()
    stream.encode("Line 1\nLine 2\tTabbed")
    #expect(stream.string == "\"Line 1\\nLine 2\\tTabbed\"")

    // Unicode characters
    stream.reset()
    stream.encode("こんにちは世界")
    #expect(stream.string == "\"こんにちは世界\"")

    // Emoji
    stream.reset()
    stream.encode("😀🚀")
    #expect(stream.string == "\"😀🚀\"")
  }

  // MARK: - Array Encoding Tests

  @Test
  func testEmptyArrayEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeArray { _ in }
    #expect(stream.string == "[]")
  }

  @Test
  func testHomogeneousArrayEncoding() {
    var stream = JSON.EncodingStream()

    // Array of integers
    stream.encodeArray { array in
      array.encodeElement { $0.encode(1) }
      array.encodeElement { $0.encode(2) }
      array.encodeElement { $0.encode(3) }
    }
    #expect(stream.string == "[1,2,3]")

    // Array of strings
    stream.reset()
    stream.encodeArray { array in
      array.encodeElement { $0.encode("a") }
      array.encodeElement { $0.encode("b") }
      array.encodeElement { $0.encode("c") }
    }
    #expect(stream.string == "[\"a\",\"b\",\"c\"]")

    // Array of booleans
    stream.reset()
    stream.encodeArray { array in
      array.encodeElement { $0.encode(true) }
      array.encodeElement { $0.encode(false) }
      array.encodeElement { $0.encode(true) }
    }
    #expect(stream.string == "[true,false,true]")
  }

  @Test
  func testHeterogeneousArrayEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeArray { array in
      array.encodeElement { $0.encode(42) }
      array.encodeElement { $0.encode("Hello") }
      array.encodeElement { $0.encode(true) }
      array.encodeElement { $0.encodeNull() }
    }

    #expect(stream.string == "[42,\"Hello\",true,null]")
  }

  // MARK: - Object Encoding Tests

  @Test
  func testEmptyObjectEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeObject { _ in }
    #expect(stream.string == "{}")
  }

  @Test
  func testSimpleObjectEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeObject { object in
      object.encodeProperty(name: "name") { $0.encode("John") }
      object.encodeProperty(name: "age") { $0.encode(30) }
      object.encodeProperty(name: "isActive") { $0.encode(true) }
    }

    #expect(stream.string == "{\"name\":\"John\",\"age\":30,\"isActive\":true}")
  }

  @Test
  func testObjectWithNullPropertyEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeObject { object in
      object.encodeProperty(name: "name") { $0.encode("Jane") }
      object.encodeProperty(name: "middleName") { $0.encodeNull() }
    }

    #expect(stream.string == "{\"name\":\"Jane\",\"middleName\":null}")
  }

  // MARK: - Nested Structure Tests

  @Test
  func testNestedArraysEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeArray { outerArray in
      outerArray.encodeElement { innerStream in
        innerStream.encodeArray { innerArray in
          innerArray.encodeElement { $0.encode(1) }
          innerArray.encodeElement { $0.encode(2) }
        }
      }
      outerArray.encodeElement { innerStream in
        innerStream.encodeArray { innerArray in
          innerArray.encodeElement { $0.encode(3) }
          innerArray.encodeElement { $0.encode(4) }
        }
      }
    }

    #expect(stream.string == "[[1,2],[3,4]]")
  }

  @Test
  func testNestedObjectsEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeObject { outerObject in
      outerObject.encodeProperty(name: "person") { innerStream in
        innerStream.encodeObject { innerObject in
          innerObject.encodeProperty(name: "name") { $0.encode("Alice") }
          innerObject.encodeProperty(name: "age") { $0.encode(25) }
        }
      }
    }

    #expect(stream.string == "{\"person\":{\"name\":\"Alice\",\"age\":25}}")
  }

  @Test
  func testArrayOfObjectsEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeArray { array in
      array.encodeElement { element in
        element.encodeObject { object in
          object.encodeProperty(name: "id") { $0.encode(1) }
          object.encodeProperty(name: "name") { $0.encode("Alice") }
        }
      }
      array.encodeElement { element in
        element.encodeObject { object in
          object.encodeProperty(name: "id") { $0.encode(2) }
          object.encodeProperty(name: "name") { $0.encode("Bob") }
        }
      }
    }

    #expect(stream.string == "[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]")
  }

  @Test
  func testObjectWithArrayPropertiesEncoding() {
    var stream = JSON.EncodingStream()

    stream.encodeObject { object in
      object.encodeProperty(name: "name") { $0.encode("Team A") }
      object.encodeProperty(name: "members") { innerStream in
        innerStream.encodeArray { array in
          array.encodeElement { $0.encode("Alice") }
          array.encodeElement { $0.encode("Bob") }
          array.encodeElement { $0.encode("Charlie") }
        }
      }
    }

    #expect(stream.string == "{\"name\":\"Team A\",\"members\":[\"Alice\",\"Bob\",\"Charlie\"]}")
  }

  // MARK: - Edge Cases and Special Character Tests

  @Test
  func testComplexNestedStructureEncoding() {
    var stream = JSON.EncodingStream()

    // Represent a complex JSON structure like:
    // {
    //   "users": [
    //     {
    //       "id": 1,
    //       "name": "Alice",
    //       "contact": {
    //         "email": "alice@example.com",
    //         "phone": null
    //       },
    //       "tags": ["admin", "active"]
    //     }
    //   ],
    //   "metadata": {
    //     "count": 1,
    //     "active": true
    //   }
    // }

    stream.encodeObject { rootObject in
      rootObject.encodeProperty(name: "users") { usersStream in
        usersStream.encodeArray { usersArray in
          usersArray.encodeElement { userElement in
            userElement.encodeObject { userObject in
              userObject.encodeProperty(name: "id") { $0.encode(1) }
              userObject.encodeProperty(name: "name") { $0.encode("Alice") }
              userObject.encodeProperty(name: "contact") { contactStream in
                contactStream.encodeObject { contactObject in
                  contactObject.encodeProperty(name: "email") { $0.encode("alice@example.com") }
                  contactObject.encodeProperty(name: "phone") { $0.encodeNull() }
                }
              }
              userObject.encodeProperty(name: "tags") { tagsStream in
                tagsStream.encodeArray { tagsArray in
                  tagsArray.encodeElement { $0.encode("admin") }
                  tagsArray.encodeElement { $0.encode("active") }
                }
              }
            }
          }
        }
      }
      rootObject.encodeProperty(name: "metadata") { metadataStream in
        metadataStream.encodeObject { metadataObject in
          metadataObject.encodeProperty(name: "count") { $0.encode(1) }
          metadataObject.encodeProperty(name: "active") { $0.encode(true) }
        }
      }
    }

    let expected =
      "{\"users\":[{\"id\":1,\"name\":\"Alice\",\"contact\":{\"email\":\"alice@example.com\",\"phone\":null},\"tags\":[\"admin\",\"active\"]}],\"metadata\":{\"count\":1,\"active\":true}}"
    #expect(stream.string == expected)
  }

  @Test
  func testSpecialCharactersInStrings() {
    var stream = JSON.EncodingStream()

    // String with special characters
    stream.encode("Line\nBreak\tTab\\Backslash\"Quote")
    #expect(stream.string == "\"Line\\nBreak\\tTab\\\\Backslash\\\"Quote\"")

    // String with JSON control characters
    stream.reset()
    stream.encode("{\"key\":\"value\"}")
    #expect(stream.string == "\"{\\\"key\\\":\\\"value\\\"}\"")
  }

  @Test
  func testResetStream() {
    var stream = JSON.EncodingStream()

    stream.encode("test")
    #expect(stream.string == "\"test\"")

    stream.reset()
    #expect(stream.string == "")

    stream.encode(42)
    #expect(stream.string == "42")
  }
}
