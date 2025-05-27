import Foundation
import Testing

@testable import JSONSupport

@Suite("Boolean Tests")
private struct BooleanTests {

  @Test
  func basicTrueTest() async throws {
    /// Complete true value
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("true")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }

    /// Partial read
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("tr")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("ue")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }
  }

  @Test
  func basicFalseTest() async throws {
    /// Complete false value
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("false")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == false)
      #expect(try decoder.isComplete)
    }

    /// Partial read
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("fal")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("se")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let value = try decoder.decodeBoolean().getValue()
      #expect(value == false)
      #expect(try decoder.isComplete)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// True - one character at a time
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("t")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("r")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("u")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("e")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }

    /// False - one character at a time
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("f")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("a")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("l")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("s")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("e")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let value = try decoder.decodeBoolean().getValue()
      #expect(value == false)
      #expect(try decoder.isComplete)
    }
  }

  @Test
  func whitespaceBeforeBooleanTest() async throws {
    /// Single space before true
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push(" true")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }

    /// Multiple spaces before false
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("   false")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == false)
      #expect(try decoder.isComplete)
    }

    /// Tab before true
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("\ttrue")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }

    /// Newline before false
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("\nfalse")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == false)
      #expect(try decoder.isComplete)
    }

    /// Mixed whitespace before true
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push(" \t\ntrue")
      decoder.stream.finish()

      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }

    /// Incremental whitespace parsing with true
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("  ")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("true")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let value = try decoder.decodeBoolean().getValue()
      #expect(value == true)
      #expect(try decoder.isComplete)
    }

    /// Incremental whitespace parsing with false
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("\t\n")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.push("false")
      #expect(try decoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let value = try decoder.decodeBoolean().getValue()
      #expect(value == false)
      #expect(try decoder.isComplete)
    }
  }

  @Test
  func testFinish() async throws {
    /// Test finish with true
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("true")
      decoder.stream.finish()
      let result = decoder.finish()
      switch result {
      case .decodingComplete(var remainder):
        switch remainder.readCharacter() {
        case .needsMoreData:
          #expect(Bool(false), "Should not need more data when stream is finished")
        case .matched:
          #expect(Bool(false), "Should not have any remaining characters")
        case .notMatched:
          // This is expected - no remaining characters in the stream
          #expect(Bool(true))
        }
      case .needsMoreData:
        #expect(Bool(false), "Should not need more data when stream is finished")
      case .decodingFailed(let error, _):
        #expect(Bool(false), "Should not fail: \(error)")
      }
    }

    /// Test finish with false
    do {
      var decoder = JSON.BooleanDecoder()
      decoder.stream.push("false")
      decoder.stream.finish()
      let result = decoder.finish()
      switch result {
      case .decodingComplete(var remainder):
        switch remainder.readCharacter() {
        case .needsMoreData:
          #expect(Bool(false), "Should not need more data when stream is finished")
        case .matched:
          #expect(Bool(false), "Should not have any remaining characters")
        case .notMatched:
          // This is expected - no remaining characters in the stream
          #expect(Bool(true))
        }
      case .needsMoreData:
        #expect(Bool(false), "Should not need more data when stream is finished")
      case .decodingFailed(let error, _):
        #expect(Bool(false), "Should not fail: \(error)")
      }
    }
  }
}

