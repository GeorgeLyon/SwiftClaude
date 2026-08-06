import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An object with tuple-typed stored properties — the macro codes them
/// through `StructuredTuple` (a bare tuple is not nominal, so it cannot
/// conform to the coding protocols), wrapping in the property getter and
/// unwrapping in `decode`. Labels code positionally, and an optional tuple
/// omits like any optional property.
@StructuredCodable
private struct Line: Equatable {
  var endpoints: (Int, Int)
  var label: (x: Int, name: String)?
  var origin: (Int, Int) = (0, 0)

  static func == (lhs: Self, rhs: Self) -> Bool {
    guard lhs.endpoints == rhs.endpoints, lhs.origin == rhs.origin else {
      return false
    }
    switch (lhs.label, rhs.label) {
    case (nil, nil): return true
    case (let lhs?, let rhs?): return lhs == rhs
    default: return false
    }
  }
}

/// A pack-generic object whose tuple property *is* the pack — wrapped and
/// unwrapped with `repeat each` rather than by element index
/// (`.variadicGenerics` compatibility is inferred from the pack).
@StructuredCodable
private struct PackTupleObject<each T: StructuredCodable> {
  var items: (repeat each T)
}

extension PackTupleObject: Equatable where repeat each T: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    for (lhs, rhs) in repeat (each lhs.items, each rhs.items) {
      guard lhs == rhs else { return false }
    }
    return true
  }
}

@Suite("Tuple Properties")
struct TuplePropertyTests {

  @Test func encodes() async throws {
    try await test(
      Line(endpoints: (1, 2), label: (x: 3, name: "point"), origin: (4, 5)),
      encodesAs: #"{"endpoints":[1,2],"label":[3,"point"],"origin":[4,5]}"#
    )
  }

  /// A `nil` tuple is omitted, like any optional property.
  @Test func encodesNilTupleAsOmitted() async throws {
    try await test(
      Line(endpoints: (1, 2)),
      encodesAs: #"{"endpoints":[1,2],"origin":[0,0]}"#
    )
  }

  @Test func decodes() async throws {
    try await test(
      #"{"endpoints":[1,2],"label":[3,"point"],"origin":[4,5]}"#,
      decodesAs: Line(endpoints: (1, 2), label: (x: 3, name: "point"), origin: (4, 5))
    )
  }

  /// An omitted optional tuple decodes to `nil`.
  @Test func decodesOmittedOptionalTuple() async throws {
    try await test(
      #"{"endpoints":[1,2],"origin":[0,0]}"#,
      decodesAs: Line(endpoints: (1, 2))
    )
  }

  /// A defaulted tuple follows the required-defaulted-property rule: the
  /// default seeds streaming, it does not permit omission.
  @Test func omittedDefaultedTupleThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"endpoints":[1,2]}"#, decodesAs: Line(endpoints: (1, 2)))
    }
  }

  /// Tuple properties get `StructuredTuple`'s `prefixItems` schema.
  @Test func schemaEncodesStructurally() async throws {
    try await test(
      Line.schema,
      encodesAs:
        #"{"properties":{"endpoints":{"prefixItems":[{"type":"integer"},{"type":"integer"}]},"label":{"prefixItems":[{"type":"integer"},{"type":"string"}]},"origin":{"prefixItems":[{"type":"integer"},{"type":"integer"}]}},"required":["endpoints","origin"]}"#
    )
  }

  @Test func packTupleEncodes() async throws {
    try await test(
      PackTupleObject<Int, String>(items: (1, "a")),
      encodesAs: #"{"items":[1,"a"]}"#
    )
  }

  @Test func packTupleDecodes() async throws {
    try await test(
      #"{"items":[1,"a"]}"#,
      decodesAs: PackTupleObject<Int, String>(items: (1, "a"))
    )
  }

}
