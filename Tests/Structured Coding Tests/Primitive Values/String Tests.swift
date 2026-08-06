import Testing

import StructuredCoding

@Suite("String")
struct StringTests {

  @Test
  func encodesSimpleString() async throws {
    try await test("hello", encodesAs: #""hello""#)
  }

  @Test
  func encodesEmptyString() async throws {
    try await test("", encodesAs: #""""#)
  }

  @Test
  func encodesEscapes() async throws {
    try await test("line1\nline2", encodesAs: #""line1\nline2""#)
  }

  @Test
  func decodesSimpleString() async throws {
    try await test("\"hello\"", decodesAs: "hello")
  }

  @Test
  func decodesEmptyString() async throws {
    try await test("\"\"", decodesAs: "")
  }

  @Test
  func decodesAcrossChunks() async throws {
    try await test(["\"hel", "lo\""], decodesAs: "hello")
  }

  @Test
  func exposesPartialValueMidStream() async throws {
    // The decoder surfaces all but the last buffered character of a pending run.
    try await test("\"hel", decodesAs: DecodingOutcome.partial("he"))
  }

}
