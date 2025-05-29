import Foundation
import Testing

@testable import JSONSupport

@Suite("Null Tests")
private struct NullTests {

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

  //  @Test
  //  func incrementalParsingTest() async throws {
  //    /// One character at a time
  //    do {
  //      var decoder = JSON.NullDecoder()
  //      decoder.stream.push("n")
  //      #expect(try decoder.decodeNull().needsMoreData)
  //
  //      decoder.stream.push("u")
  //      #expect(try decoder.decodeNull().needsMoreData)
  //
  //      decoder.stream.push("l")
  //      #expect(try decoder.decodeNull().needsMoreData)
  //
  //      decoder.stream.push("l")
  //      #expect(try decoder.decodeNull().needsMoreData)
  //
  //      decoder.stream.finish()
  //      let result = try decoder.decodeNull()
  //      #expect(try result.getValue() == ())
  //      #expect(try decoder.isComplete)
  //    }
  //  }

  // @Test
  // func whitespaceBeforeNullTest() async throws {
  //   /// Single space before null
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push(" null")
  //     decoder.stream.finish()

  //     let result = try decoder.decodeNull()
  //     #expect(try result.getValue() == ())
  //     #expect(try decoder.isComplete)
  //   }

  //   /// Multiple spaces before null
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push("   null")
  //     decoder.stream.finish()

  //     let result = try decoder.decodeNull()
  //     #expect(try result.getValue() == ())
  //     #expect(try decoder.isComplete)
  //   }

  //   /// Tab before null
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push("\tnull")
  //     decoder.stream.finish()

  //     let result = try decoder.decodeNull()
  //     #expect(try result.getValue() == ())
  //     #expect(try decoder.isComplete)
  //   }

  //   /// Newline before null
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push("\nnull")
  //     decoder.stream.finish()

  //     let result = try decoder.decodeNull()
  //     #expect(try result.getValue() == ())
  //     #expect(try decoder.isComplete)
  //   }

  //   /// Mixed whitespace before null
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push(" \t\nnull")
  //     decoder.stream.finish()

  //     let result = try decoder.decodeNull()
  //     #expect(try result.getValue() == ())
  //     #expect(try decoder.isComplete)
  //   }

  //   /// Incremental whitespace parsing
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push("  ")
  //     #expect(try decoder.decodeNull().needsMoreData)

  //     decoder.stream.push("null")
  //     #expect(try decoder.decodeNull().needsMoreData)

  //     decoder.stream.finish()
  //     let result = try decoder.decodeNull()
  //     #expect(try result.getValue() == ())
  //     #expect(try decoder.isComplete)
  //   }
  // }

  // @Test
  // func testFinish() async throws {
  //   do {
  //     var decoder = JSON.NullDecoder()
  //     decoder.stream.push("null")
  //     decoder.stream.finish()
  //     let result = decoder.finish()
  //     switch result {
  //     case .decodingComplete(var remainder):
  //       switch remainder.readCharacter() {
  //       case .needsMoreData:
  //         #expect(Bool(false), "Should not need more data when stream is finished")
  //       case .matched:
  //         #expect(Bool(false), "Should not have any remaining characters")
  //       case .notMatched:
  //         // This is expected - no remaining characters in the stream
  //         #expect(Bool(true))
  //       }
  //     case .needsMoreData:
  //       #expect(Bool(false), "Should not need more data when stream is finished")
  //     case .decodingFailed(let error, _):
  //       #expect(Bool(false), "Should not fail: \(error)")
  //     }
  //   }
  // }
}
