import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Optional")
struct OptionalSchemaTests {

  @Test
  private func testCoding() throws {
    try test(nil as String?, isCodedAs: "null")
    try test("foo" as String?, isCodedAs: "\"foo\"")
    try test("bar" as String?, isCodedAs: "\"bar\"")

    try test(nil as Int?, isCodedAs: "null")
    try test(42 as Int?, isCodedAs: "42")
    try test(-17 as Int?, isCodedAs: "-17")

    try test(nil as Bool?, isCodedAs: "null")
    try test(true as Bool?, isCodedAs: "true")
    try test(false as Bool?, isCodedAs: "false")

    try test(nil as Double?, isCodedAs: "null")
    try test(3.14 as Double?, isCodedAs: "3.14")
    try test(-2.5 as Double?, isCodedAs: "-2.5")
  }

  @Test("Non-nullable wrapper for Optional of nullable types")
  private func testNonNullableWrapper() throws {
    // When the wrapped type accepts null, Optional wraps it in an object
    // to distinguish between .none (null) and .some(null)

    // Test Optional<String?> - String? itself accepts null
    try test(.none as String??, isCodedAs: "{}")
    try test(.some(nil) as String??, isCodedAs: "{\"value\":null}")
    try test(.some("foo") as String??, isCodedAs: "{\"value\":\"foo\"}")

    // Test Optional<Int?> - Int? itself accepts null
    try test(nil as Int??, isCodedAs: "{}")
    try test(.some(nil) as Int??, isCodedAs: "{\"value\":null}")
    try test(.some(42) as Int??, isCodedAs: "{\"value\":42}")

    // Test Optional<Bool?> - Bool? itself accepts null
    try test(nil as Bool??, isCodedAs: "{}")
    try test(.some(nil) as Bool??, isCodedAs: "{\"value\":null}")
    try test(.some(true) as Bool??, isCodedAs: "{\"value\":true}")

    // Test Optional<Double?> - Double? itself accepts null
    try test(nil as Double??, isCodedAs: "{}")
    try test(.some(nil) as Double??, isCodedAs: "{\"value\":null}")
    try test(.some(3.14) as Double??, isCodedAs: "{\"value\":3.14}")

    // Test Optional<Optional<Optional<String>>> - deeply nested
    try test(nil as String???, isCodedAs: "{}")
    try test(.some(nil) as String???, isCodedAs: "{\"value\":{}}")
    try test(.some(.some(nil)) as String???, isCodedAs: "{\"value\":{\"value\":null}}")
    try test(.some(.some("test")) as String???, isCodedAs: "{\"value\":{\"value\":\"test\"}}")
  }

}
