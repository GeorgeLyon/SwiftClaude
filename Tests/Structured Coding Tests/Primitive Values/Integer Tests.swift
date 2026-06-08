import Testing

import StructuredCoding

@Suite("Integer")
struct IntegerTests {

  @Test
  func encodesPositiveInteger() throws {
    try test(42, encodesAs: "42")
  }

  @Test
  func encodesNegativeInteger() throws {
    try test(-7, encodesAs: "-7")
  }

  @Test
  func encodesZero() throws {
    try test(0, encodesAs: "0")
  }

  @Test
  func encodesOtherWidths() throws {
    try test(UInt8.max, encodesAs: "255")
    try test(Int64.min, encodesAs: "-9223372036854775808")
  }

  @Test
  func decodesPositiveInteger() throws {
    try test("42", decodesAs: 42)
  }

  @Test
  func decodesNegativeInteger() throws {
    try test("-7", decodesAs: -7)
  }

  @Test
  func decodesZero() throws {
    try test("0", decodesAs: 0)
  }

  @Test
  func decodesExponent() throws {
    try test("1e3", decodesAs: 1000)
  }

  @Test
  func decodesOtherWidths() throws {
    try test("255", decodesAs: UInt8.max)
    try test("-9223372036854775808", decodesAs: Int64.min)
  }

  @Test
  func decodesAcrossChunks() throws {
    try test(["12", "34"], decodesAs: 1234)
  }

  @Test
  func exposesNoValueMidStream() throws {
    // Integers cannot expose a partial value mid-stream.
    try test("12", decodesAs: DecodingOutcome<Int>.incomplete)
  }

}
