import Foundation
import Testing

import StructuredCoding

@Suite("Number")
struct NumberTests {

  @Test
  func encodesDouble() throws {
    try test(3.14, encodesAs: "3.14")
  }

  @Test
  func encodesNegativeDouble() throws {
    try test(-0.5, encodesAs: "-0.5")
  }

  @Test
  func encodesWholeNumberDouble() throws {
    try test(Double(42), encodesAs: "42.0")
  }

  @Test
  func encodesFloat() throws {
    try test(Float(1.5), encodesAs: "1.5")
  }

  @Test
  func encodesDecimal() throws {
    try test(Decimal(string: "123.456")!, encodesAs: "123.456")
  }

  @Test
  func decodesDecimalNumber() throws {
    try test("3.14", decodesAs: 3.14)
  }

  @Test
  func decodesNegativeNumber() throws {
    try test("-0.5", decodesAs: -0.5)
  }

  @Test
  func decodesWholeNumberAsDouble() throws {
    try test("42", decodesAs: 42.0)
  }

  @Test
  func decodesExponent() throws {
    try test("1.5e2", decodesAs: 150.0)
  }

  @Test
  func decodesFloat() throws {
    try test("1.5", decodesAs: Float(1.5))
  }

  @Test
  func decodesDecimal() throws {
    try test("123.456", decodesAs: Decimal(string: "123.456")!)
  }

  @Test
  func decodesAcrossChunks() throws {
    try test(["3.", "14"], decodesAs: 3.14)
  }

  @Test
  func exposesNoValueMidStream() throws {
    // Numbers cannot expose a partial value mid-stream.
    try test("3.1", decodesAs: DecodingOutcome<Double>.incomplete)
  }

}
