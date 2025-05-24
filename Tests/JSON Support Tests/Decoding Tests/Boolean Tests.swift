// Created by Claude

import Foundation
import Testing

@testable import JSONSupport

@Suite("Boolean Tests")
private struct BooleanTests {

  @Test
  func trueLiteralTest() async throws {
    /// Simple true
    do {
      var value = JSON.Value()
      value.stream.push("true")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == true)
    }

    /// True with leading whitespace
    do {
      var value = JSON.Value()
      value.stream.push("  true")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == true)
    }

    /// True with various whitespace
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\rtrue")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == true)
    }
  }

  @Test
  func falseLiteralTest() async throws {
    /// Simple false
    do {
      var value = JSON.Value()
      value.stream.push("false")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == false)
    }

    /// False with leading whitespace
    do {
      var value = JSON.Value()
      value.stream.push("  false")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == false)
    }

    /// False with various whitespace
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\rfalse")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == false)
    }
  }

  @Test
  func partialMatchTest() async throws {
    /// Partial true - "t"
    do {
      var value = JSON.Value()
      value.stream.push("t")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Partial true - "tr"
    do {
      var value = JSON.Value()
      value.stream.push("tr")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Partial true - "tru"
    do {
      var value = JSON.Value()
      value.stream.push("tru")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Partial false - "f"
    do {
      var value = JSON.Value()
      value.stream.push("f")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Partial false - "fa"
    do {
      var value = JSON.Value()
      value.stream.push("fa")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Partial false - "fal"
    do {
      var value = JSON.Value()
      value.stream.push("fal")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Partial false - "fals"
    do {
      var value = JSON.Value()
      value.stream.push("fals")

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Building up true incrementally
    do {
      var value = JSON.Value()

      value.stream.push("t")
      var result = try value.decodeAsBool()
      #expect(result == nil)

      value.stream.push("r")
      result = try value.decodeAsBool()
      #expect(result == nil)

      value.stream.push("u")
      result = try value.decodeAsBool()
      #expect(result == nil)

      value.stream.push("e")
      value.stream.finish()
      result = try value.decodeAsBool()
      #expect(result == true)
    }

    /// Building up false incrementally
    do {
      var value = JSON.Value()

      value.stream.push("f")
      var result = try value.decodeAsBool()
      #expect(result == nil)

      value.stream.push("al")
      result = try value.decodeAsBool()
      #expect(result == nil)

      value.stream.push("se")
      value.stream.finish()
      result = try value.decodeAsBool()
      #expect(result == false)
    }
  }

  @Test
  func invalidInputTest() async throws {
    /// Invalid starting with 't' but not 'true'
    do {
      var value = JSON.Value()
      value.stream.push("test")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Invalid starting with 'f' but not 'false'
    do {
      var value = JSON.Value()
      value.stream.push("fail")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Number input
    do {
      var value = JSON.Value()
      value.stream.push("123")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// String input
    do {
      var value = JSON.Value()
      value.stream.push("\"true\"")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Null input
    do {
      var value = JSON.Value()
      value.stream.push("null")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Empty input
    do {
      var value = JSON.Value()
      value.stream.push("")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }

    /// Only whitespace
    do {
      var value = JSON.Value()
      value.stream.push("   ")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == nil)
    }
  }

  @Test
  func caseSensitivityTest() async throws {
    /// Upper case TRUE
    do {
      var value = JSON.Value()
      value.stream.push("TRUE")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Upper case FALSE
    do {
      var value = JSON.Value()
      value.stream.push("FALSE")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Mixed case True
    do {
      var value = JSON.Value()
      value.stream.push("True")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }

    /// Mixed case False
    do {
      var value = JSON.Value()
      value.stream.push("False")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsBool()
      }
    }
  }

  @Test
  func trailingCharactersTest() async throws {
    /// true with trailing characters
    do {
      var value = JSON.Value()
      value.stream.push("true123")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == true)

      // Verify that only "true" was consumed
      let remaining = value.stream.readCharacter()
      #expect(remaining == "1")
    }

    /// false with trailing characters
    do {
      var value = JSON.Value()
      value.stream.push("false,")
      value.stream.finish()

      let result = try value.decodeAsBool()
      #expect(result == false)

      // Verify that only "false" was consumed
      let remaining = value.stream.readCharacter()
      #expect(remaining == ",")
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Just 't' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("t")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsBool()
      }
    }

    /// Just 'f' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("f")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsBool()
      }
    }

    /// 'tr' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("tr")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsBool()
      }
    }

    /// 'fals' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("fals")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsBool()
      }
    }
  }
}
