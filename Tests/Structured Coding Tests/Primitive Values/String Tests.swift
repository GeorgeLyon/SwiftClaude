import Testing

import StructuredCoding

@Suite("String")
struct StringTests {

  @Test
  func decodesSimpleString() throws {
    try test("\"hello\"", decodesAs: "hello")
  }

  @Test
  func decodesEmptyString() throws {
    try test("\"\"", decodesAs: "")
  }

  @Test
  func decodesAcrossChunks() throws {
    try test(["\"hel", "lo\""], decodesAs: "hello")
  }

  @Test
  func exposesPartialValueMidStream() throws {
    // The decoder surfaces all but the last buffered character of a pending run.
    try test("\"hel", decodesAs: DecodingOutcome.partial("he"))
  }

}
