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
      var stream = JSON.DecodingStream()
      stream.push("true")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == true)
    }

    /// True with leading whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("  true")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == true)
    }

    /// True with various whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n\rtrue")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == true)
    }
  }

  @Test
  func falseLiteralTest() async throws {
    /// Simple false
    do {
      var stream = JSON.DecodingStream()
      stream.push("false")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == false)
    }

    /// False with leading whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("  false")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == false)
    }

    /// False with various whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n\rfalse")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == false)
    }
  }

  @Test
  func partialMatchTest() async throws {
    /// Partial true - "t"
    do {
      var stream = JSON.DecodingStream()
      stream.push("t")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Partial true - "tr"
    do {
      var stream = JSON.DecodingStream()
      stream.push("tr")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Partial true - "tru"
    do {
      var stream = JSON.DecodingStream()
      stream.push("tru")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Partial false - "f"
    do {
      var stream = JSON.DecodingStream()
      stream.push("f")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Partial false - "fa"
    do {
      var stream = JSON.DecodingStream()
      stream.push("fa")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Partial false - "fal"
    do {
      var stream = JSON.DecodingStream()
      stream.push("fal")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Partial false - "fals"
    do {
      var stream = JSON.DecodingStream()
      stream.push("fals")

      let result = try stream.decodeBool()
      #expect(result == nil)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Building up true incrementally
    do {
      var stream = JSON.DecodingStream()
      
      stream.push("t")
      var result = try stream.decodeBool()
      #expect(result == nil)
      
      stream.push("r")
      result = try stream.decodeBool()
      #expect(result == nil)
      
      stream.push("u")
      result = try stream.decodeBool()
      #expect(result == nil)
      
      stream.push("e")
      stream.finish()
      result = try stream.decodeBool()
      #expect(result == true)
    }

    /// Building up false incrementally
    do {
      var stream = JSON.DecodingStream()
      
      stream.push("f")
      var result = try stream.decodeBool()
      #expect(result == nil)
      
      stream.push("al")
      result = try stream.decodeBool()
      #expect(result == nil)
      
      stream.push("se")
      stream.finish()
      result = try stream.decodeBool()
      #expect(result == false)
    }
  }

  @Test
  func invalidInputTest() async throws {
    /// Invalid starting with 't' but not 'true'
    do {
      var stream = JSON.DecodingStream()
      stream.push("test")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Invalid starting with 'f' but not 'false'
    do {
      var stream = JSON.DecodingStream()
      stream.push("fail")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Number input
    do {
      var stream = JSON.DecodingStream()
      stream.push("123")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// String input
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"true\"")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Null input
    do {
      var stream = JSON.DecodingStream()
      stream.push("null")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Empty input
    do {
      var stream = JSON.DecodingStream()
      stream.push("")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Only whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("   ")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }
  }

  @Test
  func caseInsensitivityTest() async throws {
    /// Upper case TRUE
    do {
      var stream = JSON.DecodingStream()
      stream.push("TRUE")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Upper case FALSE
    do {
      var stream = JSON.DecodingStream()
      stream.push("FALSE")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Mixed case True
    do {
      var stream = JSON.DecodingStream()
      stream.push("True")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Mixed case False
    do {
      var stream = JSON.DecodingStream()
      stream.push("False")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }
  }

  @Test
  func trailingCharactersTest() async throws {
    /// true with trailing characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("true123")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == true)
      
      // Verify that only "true" was consumed
      let remaining = stream.readCharacter()
      #expect(remaining == "1")
    }

    /// false with trailing characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("false,")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == false)
      
      // Verify that only "false" was consumed
      let remaining = stream.readCharacter()
      #expect(remaining == ",")
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Just 't' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("t")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// Just 'f' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("f")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// 'tr' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("tr")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }

    /// 'fals' at end of stream
    do {
      var stream = JSON.DecodingStream()
      stream.push("fals")
      stream.finish()

      let result = try stream.decodeBool()
      #expect(result == nil)
    }
  }
}