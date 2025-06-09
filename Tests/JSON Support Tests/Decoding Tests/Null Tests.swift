import Foundation
import Testing

@testable import JSONSupport

@Suite("Null")
struct NullTests {

  @Test
  func basicNullTest() async throws {
    /// Complete null value
    do {
      var stream = JSON.DecodingStream()
      stream.push("null")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }

    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("nu")
      #expect(try stream.decodeNull().needsMoreData)

      stream.push("ll")
      #expect(try stream.decodeNull().needsMoreData)

      stream.finish()
      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// One character at a time
    do {
      var stream = JSON.DecodingStream()
      stream.push("n")
      #expect(try stream.decodeNull().needsMoreData)

      stream.push("u")
      #expect(try stream.decodeNull().needsMoreData)

      stream.push("l")
      #expect(try stream.decodeNull().needsMoreData)

      stream.push("l")
      #expect(try stream.decodeNull().needsMoreData)

      stream.finish()
      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }
  }

  @Test
  func whitespaceBeforeNullTest() async throws {
    /// Single space before null
    do {
      var stream = JSON.DecodingStream()
      stream.push(" null")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }

    /// Multiple spaces before null
    do {
      var stream = JSON.DecodingStream()
      stream.push("   null")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }

    /// Tab before null
    do {
      var stream = JSON.DecodingStream()
      stream.push("\tnull")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }

    /// Newline before null
    do {
      var stream = JSON.DecodingStream()
      stream.push("\nnull")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }

    /// Mixed whitespace before null
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\nnull")
      stream.finish()

      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }

    /// Incremental whitespace parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("  ")
      #expect(try stream.decodeNull().needsMoreData)

      stream.push("null")
      #expect(try stream.decodeNull().needsMoreData)

      stream.finish()
      let result = try stream.decodeNull()
      #expect(try result.getValue() == ())
    }
  }

}
