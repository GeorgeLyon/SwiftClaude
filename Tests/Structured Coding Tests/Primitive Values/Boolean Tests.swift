import Testing

import StructuredCoding

@Suite("Boolean")
struct BooleanTests {

  @Test
  func encodesTrue() async throws {
    try await test(true, encodesAs: "true")
  }

  @Test
  func encodesFalse() async throws {
    try await test(false, encodesAs: "false")
  }

  @Test
  func decodesTrue() async throws {
    try await test("true", decodesAs: true)
  }

  @Test
  func decodesFalse() async throws {
    try await test("false", decodesAs: false)
  }

  @Test
  func decodesAcrossChunks() async throws {
    try await test(["tr", "ue"], decodesAs: true)
  }

  @Test
  func exposesNoValueMidStream() async throws {
    // Booleans cannot expose a partial value mid-stream.
    try await test("tru", decodesAs: DecodingOutcome<Bool>.incomplete)
  }

}
