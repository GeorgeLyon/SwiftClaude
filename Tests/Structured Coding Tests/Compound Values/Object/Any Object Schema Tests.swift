import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// `AnyStructuredObjectSchema` type-erases a `StructuredObject`'s schema, so it
/// must encode byte-for-byte the same JSON as the object's own structural
/// schema — only the static type is hidden.
@Suite("Any Object Schema")
struct AnyObjectSchemaTests {

  @Test func encodesStructurallyLikeTheObjectSchema() throws {
    try test(
      AnyStructuredObjectSchema(MutableStringObject.self),
      encodesAs:
        #"{"properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}"#
    )
  }

  @Test func forwardsDescription() throws {
    try test(
      AnyStructuredObjectSchema(MutableStringObject.self, description: "A mutable pair of strings"),
      encodesAs:
        #"{"description":"A mutable pair of strings","properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}"#
    )
  }

  @Test func erasesEmptyObjectSchema() throws {
    try test(
      AnyStructuredObjectSchema(EmptyObject.self),
      encodesAs: #"{"properties":{}}"#
    )
  }

}
