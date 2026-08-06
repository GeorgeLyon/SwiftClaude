import Foundation
import Testing

import StructuredCoding

@Suite("Number")
struct NumberTests {

  @Test
  func encodesDouble() async throws {
    try await test(3.14, encodesAs: "3.14")
  }

  @Test
  func encodesNegativeDouble() async throws {
    try await test(-0.5, encodesAs: "-0.5")
  }

  @Test
  func encodesWholeNumberDouble() async throws {
    try await test(Double(42), encodesAs: "42.0")
  }

  @Test
  func encodesFloat() async throws {
    try await test(Float(1.5), encodesAs: "1.5")
  }

  @Test
  func encodesDecimal() async throws {
    try await test(Decimal(string: "123.456")!, encodesAs: "123.456")
  }

  @Test
  func decodesDecimalNumber() async throws {
    try await test("3.14", decodesAs: 3.14)
  }

  @Test
  func decodesNegativeNumber() async throws {
    try await test("-0.5", decodesAs: -0.5)
  }

  @Test
  func decodesWholeNumberAsDouble() async throws {
    try await test("42", decodesAs: 42.0)
  }

  @Test
  func decodesExponent() async throws {
    try await test("1.5e2", decodesAs: 150.0)
  }

  @Test
  func decodesFloat() async throws {
    try await test("1.5", decodesAs: Float(1.5))
  }

  @Test
  func decodesDecimal() async throws {
    try await test("123.456", decodesAs: Decimal(string: "123.456")!)
  }

  @Test
  func decodesAcrossChunks() async throws {
    try await test(["3.", "14"], decodesAs: 3.14)
  }

  @Test
  func exposesNoValueMidStream() async throws {
    // Numbers cannot expose a partial value mid-stream.
    try await test("3.1", decodesAs: DecodingOutcome<Double>.incomplete)
  }

}
