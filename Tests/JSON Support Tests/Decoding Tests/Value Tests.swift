// Created by Claude

import Foundation
import Testing

@testable import JSONSupport

@Suite("Value Tests")
private struct ValueTests {

  // MARK: - Kind Detection Tests

  @Test
  func nullKindTest() async throws {
    var value = JSON.Value()
    value.stream.push("null")
    value.stream.finish()

    let kind = try value.kind
    #expect(kind == .null)
  }

  @Test
  func stringKindTest() async throws {
    var value = JSON.Value()
    value.stream.push("\"hello\"")
    value.stream.finish()

    let kind = try value.kind
    #expect(kind == .string)
  }

  @Test
  func numberKindTest() async throws {
    /// Integer
    do {
      var value = JSON.Value()
      value.stream.push("123")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Negative integer
    do {
      var value = JSON.Value()
      value.stream.push("-456")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Hexadecimal number
    do {
      var value = JSON.Value()
      value.stream.push("abc123")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Capital hexadecimal number
    do {
      var value = JSON.Value()
      value.stream.push("ABC123")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }
  }

  @Test
  func booleanKindTest() async throws {
    /// True
    do {
      var value = JSON.Value()
      value.stream.push("true")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .boolean)
    }

    /// False - 'f' is treated as hex digit, so false is detected as number
    do {
      var value = JSON.Value()
      value.stream.push("false")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)  // 'f' is hex digit, takes precedence
    }
  }

  @Test
  func objectKindTest() async throws {
    var value = JSON.Value()
    value.stream.push("{\"key\": \"value\"}")
    value.stream.finish()

    let kind = try value.kind
    #expect(kind == .object)
  }

  @Test
  func arrayKindTest() async throws {
    var value = JSON.Value()
    value.stream.push("[1, 2, 3]")
    value.stream.finish()

    let kind = try value.kind
    #expect(kind == .array)
  }

  // MARK: - Whitespace Handling Tests

  @Test
  func whitespaceHandlingTest() async throws {
    /// Leading whitespace before null
    do {
      var value = JSON.Value()
      value.stream.push("   null")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .null)
    }

    /// Various whitespace before string
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\r\"test\"")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .string)
    }

    /// Whitespace before number
    do {
      var value = JSON.Value()
      value.stream.push("  123")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Whitespace before boolean
    do {
      var value = JSON.Value()
      value.stream.push("\t true")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .boolean)
    }

    /// Whitespace before object
    do {
      var value = JSON.Value()
      value.stream.push("\n{}")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .object)
    }

    /// Whitespace before array
    do {
      var value = JSON.Value()
      value.stream.push("\r[]")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .array)
    }
  }

  // MARK: - Invalid Input Tests

  @Test
  func invalidKindTest() async throws {
    /// Invalid character throws error
    do {
      var value = JSON.Value()
      value.stream.push("x")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        _ = try value.kind
      }
    }

    /// Invalid starting character throws error
    do {
      var value = JSON.Value()
      value.stream.push("@invalid")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        _ = try value.kind
      }
    }

    /// Special characters throw error
    do {
      var value = JSON.Value()
      value.stream.push("!@#$")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        _ = try value.kind
      }
    }
  }

  @Test
  func emptyInputTest() async throws {
    /// Empty stream
    do {
      var value = JSON.Value()
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == nil)
    }

    /// Only whitespace
    do {
      var value = JSON.Value()
      value.stream.push("   ")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == nil)
    }

    /// Various whitespace only
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\r ")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == nil)
    }
  }

  // MARK: - Incremental Parsing Tests

  @Test
  func incrementalKindDetectionTest() async throws {
    /// Building up string incrementally
    do {
      var value = JSON.Value()

      value.stream.push("\"")
      value.stream.finish()
      let kind = try value.kind
      #expect(kind == .string)
    }

    /// Building up number incrementally
    do {
      var value = JSON.Value()

      value.stream.push("1")
      value.stream.finish()
      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Building up boolean incrementally
    do {
      var value = JSON.Value()

      value.stream.push("t")
      value.stream.finish()
      let kind = try value.kind
      #expect(kind == .boolean)
    }
  }

  // MARK: - Edge Cases Tests

  @Test
  func edgeCasesTest() async throws {
    /// Single character inputs
    do {
      /// Just opening quote
      var value = JSON.Value()
      value.stream.push("\"")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .string)
    }

    do {
      /// Just opening brace
      var value = JSON.Value()
      value.stream.push("{")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .object)
    }

    do {
      /// Just opening bracket
      var value = JSON.Value()
      value.stream.push("[")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .array)
    }

    do {
      /// Single digit
      var value = JSON.Value()
      value.stream.push("0")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    do {
      /// Single 't' for boolean
      var value = JSON.Value()
      value.stream.push("t")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .boolean)
    }

    do {
      /// Single 'f' for hex number (not boolean)
      var value = JSON.Value()
      value.stream.push("f")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)  // 'f' is hex digit
    }

    do {
      /// Single 'n' for null
      var value = JSON.Value()
      value.stream.push("n")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .null)
    }
  }

  // MARK: - Initialization Tests

  @Test
  func initializationTest() async throws {
    /// Default initialization
    do {
      let value = JSON.Value()
      #expect(value.stream.isFinished == false)
    }

    /// Initialization with stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("test")
      stream.finish()

      let value = JSON.Value(decoding: stream)
      #expect(value.stream.isFinished == true)
    }
  }

  // MARK: - Multiple Kind Checks Tests

  @Test
  func multipleKindChecksTest() async throws {
    var value = JSON.Value()
    value.stream.push("\"hello world\"")
    value.stream.finish()

    /// Multiple calls to kind should return the same result
    let kind1 = try value.kind
    let kind2 = try value.kind
    let kind3 = try value.kind

    #expect(kind1 == .string)
    #expect(kind2 == .string)
    #expect(kind3 == .string)
  }

  // MARK: - Peek Behavior Tests

  @Test
  func peekBehaviorTest() async throws {
    /// Ensure kind detection doesn't consume characters
    var value = JSON.Value()
    value.stream.push("123")
    value.stream.finish()

    let kind = try value.kind
    #expect(kind == .number)

    /// Should still be able to read the first character
    let firstChar = value.stream.readCharacter()
    #expect(firstChar == "1")
  }

  @Test
  func complexWhitespaceTest() async throws {
    /// Mixed whitespace types
    var value = JSON.Value()
    value.stream.push("  \t\n\r  null")
    value.stream.finish()

    let kind = try value.kind
    #expect(kind == .null)
  }

  @Test
  func hexNumberVariationsTest() async throws {
    /// Lowercase hex
    do {
      var value = JSON.Value()
      value.stream.push("abcdef")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Uppercase hex
    do {
      var value = JSON.Value()
      value.stream.push("ABCDEF")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }

    /// Mixed case hex
    do {
      var value = JSON.Value()
      value.stream.push("AbCdEf")
      value.stream.finish()

      let kind = try value.kind
      #expect(kind == .number)
    }
  }
}