import Testing

import StructuredCoding

@Suite("Integer")
struct IntegerTests {

  @Test
  func encodesPositiveInteger() async throws {
    try await test(42, encodesAs: "42")
  }

  @Test
  func encodesNegativeInteger() async throws {
    try await test(-7, encodesAs: "-7")
  }

  @Test
  func encodesZero() async throws {
    try await test(0, encodesAs: "0")
  }

  @Test
  func encodesOtherWidths() async throws {
    try await test(UInt8.max, encodesAs: "255")
    try await test(Int64.min, encodesAs: "-9223372036854775808")
  }

  @Test
  func decodesPositiveInteger() async throws {
    try await test("42", decodesAs: 42)
  }

  @Test
  func decodesNegativeInteger() async throws {
    try await test("-7", decodesAs: -7)
  }

  @Test
  func decodesZero() async throws {
    try await test("0", decodesAs: 0)
  }

  @Test
  func decodesExponent() async throws {
    try await test("1e3", decodesAs: 1000)
  }

  @Test
  func decodesOtherWidths() async throws {
    try await test("255", decodesAs: UInt8.max)
    try await test("-9223372036854775808", decodesAs: Int64.min)
  }

  @Test
  func decodesAcrossChunks() async throws {
    try await test(["12", "34"], decodesAs: 1234)
  }

  @Test
  func exposesNoValueMidStream() async throws {
    // Integers cannot expose a partial value mid-stream.
    try await test("12", decodesAs: DecodingOutcome<Int>.incomplete)
  }

}
