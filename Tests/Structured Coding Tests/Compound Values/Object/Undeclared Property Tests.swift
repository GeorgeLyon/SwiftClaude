import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// `undeclaredPropertyBehavior: .discard` makes an object's decoder skip
/// properties the type does not declare instead of failing. The setting is
/// per-type: everything else about decoding — required properties, duplicate
/// detection, streaming vs. buffered construction — is unchanged.
@Suite("Undeclared Properties")
struct UndeclaredPropertyTests {

  // MARK: - Streamed path (constructible up front)

  @Test func discardsUnknownBeforeDeclaredProperties() async throws {
    try await test(
      #"{"junk":1,"first":"a","second":"b"}"#,
      decodesAs: DiscardingStreamedObject(first: "a", second: "b")
    )
  }

  @Test func discardsUnknownBetweenDeclaredProperties() async throws {
    try await test(
      #"{"first":"a","junk":true,"second":"b"}"#,
      decodesAs: DiscardingStreamedObject(first: "a", second: "b")
    )
  }

  @Test func discardsUnknownAfterDeclaredProperties() async throws {
    try await test(
      #"{"first":"a","second":"b","junk":null}"#,
      decodesAs: DiscardingStreamedObject(first: "a", second: "b")
    )
  }

  /// The skipped value can be arbitrarily nested — the whole subtree is
  /// consumed.
  @Test func discardsNestedUnknownValue() async throws {
    try await test(
      #"{"first":"a","junk":{"nested":{"deep":[1,2,{"x":null}]}},"second":"b"}"#,
      decodesAs: DiscardingStreamedObject(first: "a", second: "b")
    )
  }

  @Test func discardsMultipleUnknownProperties() async throws {
    try await test(
      #"{"i":1,"first":"a","j":[],"k":"x","second":"b"}"#,
      decodesAs: DiscardingStreamedObject(first: "a", second: "b")
    )
  }

  /// Discarding an unknown property does not disturb optional-omission — the
  /// omitted `second` still decodes as `nil`.
  @Test func discardsWithOmittedOptionalProperty() async throws {
    try await test(
      #"{"junk":1,"first":"a"}"#,
      decodesAs: DiscardingStreamedObject(first: "a", second: nil)
    )
  }

  // MARK: - Buffered path (constructed mid-stream)

  @Test func discardsUnknownBeforeBufferedProperties() async throws {
    try await test(
      #"{"junk":{},"a":1,"b":2}"#,
      decodesAs: DiscardingBufferedObject(a: 1, b: 2)
    )
  }

  @Test func discardsUnknownBetweenBufferedProperties() async throws {
    try await test(
      #"{"a":1,"junk":[false],"b":2}"#,
      decodesAs: DiscardingBufferedObject(a: 1, b: 2)
    )
  }

  @Test func discardsUnknownAfterBufferedProperties() async throws {
    try await test(
      #"{"a":1,"b":2,"junk":"x"}"#,
      decodesAs: DiscardingBufferedObject(a: 1, b: 2)
    )
  }

  // MARK: - Zero-property objects

  @Test func emptyObjectStillDecodesFromEmptyJSON() async throws {
    try await test(
      #"{}"#,
      decodesAs: DiscardingEmptyObject()
    )
  }

  @Test func emptyObjectDiscardsEveryProperty() async throws {
    try await test(
      #"{"any":1,"other":[false],"more":{"a":"b"}}"#,
      decodesAs: DiscardingEmptyObject()
    )
  }

  // MARK: - Unchanged failure modes

  /// Discarding is only for *undeclared* properties — a duplicated declared
  /// property is still an error.
  @Test func duplicateDeclaredPropertyStillThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"first":"a","first":"b"}"#,
        decodesAs: DiscardingStreamedObject(first: "b", second: nil)
      )
    }
  }

  /// A missing required property is still an error, however many unknowns
  /// were discarded along the way.
  @Test func missingRequiredPropertyStillThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"junk":1}"#,
        decodesAs: DiscardingBufferedObject(a: 0, b: 0)
      )
    }
  }
}

// MARK: - Fixtures

/// Branch A: both properties have initial values, so the object is constructed
/// up front and unknown properties are discarded mid-stream.
@StructuredCodable(undeclaredPropertyBehavior: .discard)
private struct DiscardingStreamedObject: Equatable, Sendable {
  var first: String
  var second: String?
}

/// Branch B: `let Int` properties have no initial value, so unknown properties
/// are discarded while declared ones buffer toward construction.
@StructuredCodable(undeclaredPropertyBehavior: .discard)
private struct DiscardingBufferedObject: Equatable, Sendable {
  let a: Int
  let b: Int
}

/// No declared properties at all — every property is undeclared and discarded.
@StructuredCodable(undeclaredPropertyBehavior: .discard)
private struct DiscardingEmptyObject: Equatable, Sendable {
}
