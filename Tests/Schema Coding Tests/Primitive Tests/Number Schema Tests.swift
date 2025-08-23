import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Number")
struct NumberSchemaTests {

  @Test("Double")
  private func testDouble() throws {
    try test(3.14, isCodedAs: "3.14")
    try test(0.0, isCodedAs: "0.0")
    try test(-1.5, isCodedAs: "-1.5")
    try test(1e10, isCodedAs: "10000000000.0")
  }

  @Test("Float")
  private func testFloat() throws {
    try test(Float(3.14), isCodedAs: "3.14")
    try test(Float(0.0), isCodedAs: "0.0")
    try test(Float(-1.5), isCodedAs: "-1.5")
  }

  @Test("Non-roundtripping exponential notation - Double")
  private func testDoubleExponentialNotation() throws {
    // Exponential notation should decode correctly even though it won't re-encode the same way
    try test("1e5", decodesAs: 100000.0)
    try test("1.5e3", decodesAs: 1500.0)
    try test("2.5e-2", decodesAs: 0.025)
    try test("-3.14e2", decodesAs: -314.0)
    try test("1.602e-19", decodesAs: 1.602e-19)
    try test("-9.8e0", decodesAs: -9.8)
    try test("4.2e1", decodesAs: 42.0)
    try test("1e-10", decodesAs: 1e-10)
    try test("9.999e99", decodesAs: 9.999e99)
  }

  @Test("Non-roundtripping exponential notation - Float")
  private func testFloatExponentialNotation() throws {
    // Test Float-specific exponential notation decoding
    try test("1e5", decodesAs: Float(100000.0))
    try test("1.5e3", decodesAs: Float(1500.0))
    try test("-3.14e2", decodesAs: Float(-314.0))
    try test("1.23e-4", decodesAs: Float(0.000123))
    try test("7.5e6", decodesAs: Float(7500000.0))
    try test("-1e-3", decodesAs: Float(-0.001))
    try test("5e0", decodesAs: Float(5.0))
    try test("1.1e-38", decodesAs: Float(1.1e-38))  // Near Float.min
  }

  @Test
  private func testSchema() throws {
    try SchemaCoding.Support
      .schema(
        representing: Double.self
      )
      .test(encodesAs: #"{"type":"number"}"#)

    try SchemaCoding.Support
      .schema(
        representing: Double.self,
        description: "A number"
      )
      .test(encodesAs: #"{"description":"A number","type":"number"}"#)

    try SchemaCoding.Support
      .schema(
        representing: Float.self
      )
      .test(encodesAs: #"{"type":"number"}"#)

    try SchemaCoding.Support
      .schema(
        representing: Float.self,
        description: "A float number"
      )
      .test(encodesAs: #"{"description":"A float number","type":"number"}"#)
  }

}
