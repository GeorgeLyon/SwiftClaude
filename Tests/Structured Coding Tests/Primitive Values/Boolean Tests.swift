import Testing

import StructuredCoding

@Suite("Boolean")
struct BooleanTests {

  @Test
  func encodesTrue() throws {
    try test(true, encodesAs: "true")
  }

  @Test
  func encodesFalse() throws {
    try test(false, encodesAs: "false")
  }

  @Test
  func decodesTrue() throws {
    try test("true", decodesAs: true)
  }

  @Test
  func decodesFalse() throws {
    try test("false", decodesAs: false)
  }

  @Test
  func decodesAcrossChunks() throws {
    try test(["tr", "ue"], decodesAs: true)
  }

  @Test
  func exposesNoValueMidStream() throws {
    // Booleans cannot expose a partial value mid-stream.
    try test("tru", decodesAs: DecodingOutcome<Bool>.incomplete)
  }

}
