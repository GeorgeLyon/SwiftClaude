// Created by Claude

import Foundation
import Testing

@testable import JSONSupport

@Suite("Null Tests")
private struct NullTests {

  @Test
  func nullLiteralTest() async throws {
    /// Simple null
    do {
      var value = JSON.Value()
      value.stream.push("null")
      value.stream.finish()

      let result = try value.decodeAsNull()
      #expect(result == true)
    }

    /// Null with leading whitespace
    do {
      var value = JSON.Value()
      value.stream.push("  null")
      value.stream.finish()

      let result = try value.decodeAsNull()
      #expect(result == true)
    }

    /// Null with various whitespace
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\rnull")
      value.stream.finish()

      let result = try value.decodeAsNull()
      #expect(result == true)
    }
  }

  @Test
  func partialMatchTest() async throws {
    /// Partial null - "n"
    do {
      var value = JSON.Value()
      value.stream.push("n")

      let result = try value.decodeAsNull()
      #expect(result == false)
    }

    /// Partial null - "nu"
    do {
      var value = JSON.Value()
      value.stream.push("nu")

      let result = try value.decodeAsNull()
      #expect(result == false)
    }

    /// Partial null - "nul"
    do {
      var value = JSON.Value()
      value.stream.push("nul")

      let result = try value.decodeAsNull()
      #expect(result == false)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Building up null incrementally
    do {
      var value = JSON.Value()

      value.stream.push("n")
      var result = try value.decodeAsNull()
      #expect(result == false)

      value.stream.push("u")
      result = try value.decodeAsNull()
      #expect(result == false)

      value.stream.push("l")
      result = try value.decodeAsNull()
      #expect(result == false)

      value.stream.push("l")
      value.stream.finish()
      result = try value.decodeAsNull()
      #expect(result == true)
    }

    /// Building up null in chunks
    do {
      var value = JSON.Value()

      value.stream.push("nu")
      var result = try value.decodeAsNull()
      #expect(result == false)

      value.stream.push("ll")
      value.stream.finish()
      result = try value.decodeAsNull()
      #expect(result == true)
    }
  }

  @Test
  func invalidInputTest() async throws {
    /// Invalid starting with 'n' but not 'null'
    do {
      var value = JSON.Value()
      value.stream.push("none")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Invalid starting with 'n' but not 'null'
    do {
      var value = JSON.Value()
      value.stream.push("nil")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Boolean input
    do {
      var value = JSON.Value()
      value.stream.push("true")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Number input
    do {
      var value = JSON.Value()
      value.stream.push("123")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// String input
    do {
      var value = JSON.Value()
      value.stream.push("\"null\"")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Empty input
    do {
      var value = JSON.Value()
      value.stream.push("")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsNull()
      }
    }

    /// Only whitespace
    do {
      var value = JSON.Value()
      value.stream.push("   ")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsNull()
      }
    }
  }

  @Test
  func caseInsensitivityTest() async throws {
    /// Upper case NULL
    do {
      var value = JSON.Value()
      value.stream.push("NULL")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Mixed case Null
    do {
      var value = JSON.Value()
      value.stream.push("Null")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Mixed case nULL
    do {
      var value = JSON.Value()
      value.stream.push("nULL")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }
  }

  @Test
  func trailingCharactersTest() async throws {
    /// null with trailing characters
    do {
      var value = JSON.Value()
      value.stream.push("null123")
      value.stream.finish()

      let result = try value.decodeAsNull()
      #expect(result == true)

      // Verify that only "null" was consumed
      let remaining = value.stream.readCharacter()
      #expect(remaining == "1")
    }

    /// null with comma
    do {
      var value = JSON.Value()
      value.stream.push("null,")
      value.stream.finish()

      let result = try value.decodeAsNull()
      #expect(result == true)

      // Verify that only "null" was consumed
      let remaining = value.stream.readCharacter()
      #expect(remaining == ",")
    }

    /// null with closing bracket
    do {
      var value = JSON.Value()
      value.stream.push("null]")
      value.stream.finish()

      let result = try value.decodeAsNull()
      #expect(result == true)

      // Verify that only "null" was consumed
      let remaining = value.stream.readCharacter()
      #expect(remaining == "]")
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Just 'n' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("n")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsNull()
      }
    }

    /// 'nu' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("nu")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsNull()
      }
    }

    /// 'nul' at end of stream
    do {
      var value = JSON.Value()
      value.stream.push("nul")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsNull()
      }
    }

    /// 'null' with no finish
    do {
      var value = JSON.Value()
      value.stream.push("null")
      // Don't call finish()

      let result = try value.decodeAsNull()
      #expect(result == false)
    }
  }

  @Test
  func similarWordsTest() async throws {
    /// Word starting with 'n' - "new"
    do {
      var value = JSON.Value()
      value.stream.push("new")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Word starting with 'n' - "nothing"
    do {
      var value = JSON.Value()
      value.stream.push("nothing")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }

    /// Word starting with 'nu' - "number"
    do {
      var value = JSON.Value()
      value.stream.push("number")
      value.stream.finish()

      #expect(throws: (any Error).self) {
        try value.decodeAsNull()
      }
    }
  }
}
