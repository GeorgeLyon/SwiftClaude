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
      var stream = JSON.DecodingStream()
      stream.push("null")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == true)
    }

    /// Null with leading whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("  null")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == true)
    }

    /// Null with various whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n\rnull")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == true)
    }
  }

  @Test
  func partialMatchTest() async throws {
    /// Partial null - "n"
    do {
      var stream = JSON.DecodingStream()
      stream.push("n")

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Partial null - "nu"
    do {
      var stream = JSON.DecodingStream()
      stream.push("nu")

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Partial null - "nul"
    do {
      var stream = JSON.DecodingStream()
      stream.push("nul")

      let result = try stream.decodeNull()
      #expect(result == false)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Building up null incrementally
    do {
      var stream = JSON.DecodingStream()
      
      stream.push("n")
      var result = try stream.decodeNull()
      #expect(result == false)
      
      stream.push("u")
      result = try stream.decodeNull()
      #expect(result == false)
      
      stream.push("l")
      result = try stream.decodeNull()
      #expect(result == false)
      
      stream.push("l")
      stream.finish()
      result = try stream.decodeNull()
      #expect(result == true)
    }

    /// Building up null in chunks
    do {
      var stream = JSON.DecodingStream()
      
      stream.push("nu")
      var result = try stream.decodeNull()
      #expect(result == false)
      
      stream.push("ll")
      stream.finish()
      result = try stream.decodeNull()
      #expect(result == true)
    }
  }

  @Test
  func invalidInputTest() async throws {
    /// Invalid starting with 'n' but not 'null'
    do {
      var stream = JSON.DecodingStream()
      stream.push("none")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Invalid starting with 'n' but not 'null'
    do {
      var stream = JSON.DecodingStream()
      stream.push("nil")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Boolean input
    do {
      var stream = JSON.DecodingStream()
      stream.push("true")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Number input
    do {
      var stream = JSON.DecodingStream()
      stream.push("123")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// String input
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"null\"")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Empty input
    do {
      var stream = JSON.DecodingStream()
      stream.push("")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Only whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("   ")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }
  }

  @Test
  func caseInsensitivityTest() async throws {
    /// Upper case NULL
    do {
      var stream = JSON.DecodingStream()
      stream.push("NULL")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Mixed case Null
    do {
      var stream = JSON.DecodingStream()
      stream.push("Null")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Mixed case nULL
    do {
      var stream = JSON.DecodingStream()
      stream.push("nULL")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }
  }

  @Test
  func trailingCharactersTest() async throws {
    /// null with trailing characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("null123")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == true)
      
      // Verify that only "null" was consumed
      let remaining = stream.readCharacter()
      #expect(remaining == "1")
    }

    /// null with comma
    do {
      var stream = JSON.DecodingStream()
      stream.push("null,")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == true)
      
      // Verify that only "null" was consumed
      let remaining = stream.readCharacter()
      #expect(remaining == ",")
    }

    /// null with closing bracket
    do {
      var stream = JSON.DecodingStream()
      stream.push("null]")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == true)
      
      // Verify that only "null" was consumed
      let remaining = stream.readCharacter()
      #expect(remaining == "]")
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Just 'n' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("n")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// 'nu' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("nu")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// 'nul' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("nul")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// 'null' with no finish
    do {
      var stream = JSON.DecodingStream()
      stream.push("null")
      // Don't call finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }
  }

  @Test
  func similarWordsTest() async throws {
    /// Word starting with 'n' - "new"
    do {
      var stream = JSON.DecodingStream()
      stream.push("new")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Word starting with 'n' - "nothing"
    do {
      var stream = JSON.DecodingStream()
      stream.push("nothing")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }

    /// Word starting with 'nu' - "number"
    do {
      var stream = JSON.DecodingStream()
      stream.push("number")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(result == false)
    }
  }
}