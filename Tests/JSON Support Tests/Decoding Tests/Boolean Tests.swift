import Foundation
import Testing

@testable import JSONSupport

@Suite("Boolean")
struct BooleanTests {

  @Test
  func basicTrueTest() async throws {
    /// Complete true value
    do {
      var stream = JSON.DecodingStream()
      stream.push("true")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }

    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("tr")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("ue")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.finish()
      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }
  }

  @Test
  func basicFalseTest() async throws {
    /// Complete false value
    do {
      var stream = JSON.DecodingStream()
      stream.push("false")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == false)
    }

    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("fal")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("se")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.finish()
      let value = try stream.decodeBoolean().getValue()
      #expect(value == false)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// True - one character at a time
    do {
      var stream = JSON.DecodingStream()
      stream.push("t")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("r")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("u")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("e")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.finish()
      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }

    /// False - one character at a time
    do {
      var stream = JSON.DecodingStream()
      stream.push("f")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("a")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("l")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("s")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("e")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.finish()
      let value = try stream.decodeBoolean().getValue()
      #expect(value == false)
    }
  }

  @Test
  func whitespaceBeforeBooleanTest() async throws {
    /// Single space before true
    do {
      var stream = JSON.DecodingStream()
      stream.push(" true")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }

    /// Multiple spaces before false
    do {
      var stream = JSON.DecodingStream()
      stream.push("   false")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == false)
    }

    /// Tab before true
    do {
      var stream = JSON.DecodingStream()
      stream.push("\ttrue")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }

    /// Newline before false
    do {
      var stream = JSON.DecodingStream()
      stream.push("\nfalse")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == false)
    }

    /// Mixed whitespace before true
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\ntrue")
      stream.finish()

      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }

    /// Incremental whitespace parsing with true
    do {
      var stream = JSON.DecodingStream()
      stream.push("  ")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("true")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.finish()
      let value = try stream.decodeBoolean().getValue()
      #expect(value == true)
    }

    /// Incremental whitespace parsing with false
    do {
      var stream = JSON.DecodingStream()
      stream.push("\t\n")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.push("false")
      #expect(try stream.decodeBoolean().needsMoreData)

      stream.finish()
      let value = try stream.decodeBoolean().getValue()
      #expect(value == false)
    }
  }

}
