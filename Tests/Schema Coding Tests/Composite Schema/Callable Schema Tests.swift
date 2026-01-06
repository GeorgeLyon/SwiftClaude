import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Callable Schema")
struct CallableSchemaTests {

  @SchemaCallable
  func foo(bar: Bool, _ baz: Bool) -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  @SchemaCallable
  func asyncFoo(bar: Bool, _ baz: Bool) async -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  @SchemaCallable
  func throwingFoo(bar: Bool, _ baz: Bool) throws -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  @SchemaCallable
  func throwingAsyncFoo(bar: Bool, _ baz: Bool) async throws -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  @SchemaCallable
  func typedThrowingFoo(bar: Bool, _ baz: Bool) throws(TypedError) -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  @SchemaCallable
  func typedThrowingAsyncFoo(bar: Bool, _ baz: Bool) async throws(TypedError) -> (a: Bool, b: Bool)
  {
    (!bar, !baz)
  }

  @SchemaCallable
  static func staticFoo(bar: Bool, _ baz: Bool) -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  @SchemaCallable
  static func asyncStaticFoo(bar: Bool, _ baz: Bool) async -> (a: Bool, b: Bool) {
    (!bar, !baz)
  }

  struct TypedError: Error {

  }

}
