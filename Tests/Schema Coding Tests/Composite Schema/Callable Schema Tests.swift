import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Callable Schema")
struct CallableSchemaTests {

  @Test
  func callableSchema() {
    /// Sync
    func foo(bar: Bool, _ baz: Bool) -> (a: Bool, b: Bool) {
      (!bar, !baz)
    }
    func __schema__foo(
      bar: Bool.Type = Bool.self,
      _ baz: Bool.Type = Bool.self
    )
      -> SchemaCoding.Support.CallableSchema<
        Void,
        some SchemaCoding.Schema<(Bool, Bool)>,
        some SchemaCoding.Schema<(Bool, Bool)>,
        (Bool, Bool),
        Never
      >
    {
      let inputSchema = SchemaCoding.Support.parameterClauseSchema {
        SchemaCoding.Support.parameter(
          label: "bar",
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
        SchemaCoding.Support.parameter(
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
      }
      let outputSchema = SchemaCoding.Support.parameterClauseSchema {
        SchemaCoding.Support.parameter(
          label: "a",
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
        SchemaCoding.Support.parameter(
          label: "b",
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
      }
      return SchemaCoding.Support.CallableSchema(
        name: "foo(bar:_:)",
        inputSchema: inputSchema,
        outputSchema: outputSchema,
        invoke: foo(bar:_:)
      )
    }

    /// Async
    func fooAsync(bar: Bool, _ baz: Bool) async -> (a: Bool, b: Bool) {
      (!bar, !baz)
    }
    func __schema__fooAsync(
      bar: Bool.Type = Bool.self,
      _ baz: Bool.Type = Bool.self
    )
      -> SchemaCoding.Support.CallableSchema<
        Void,
        some SchemaCoding.Schema<(Bool, Bool)>,
        some SchemaCoding.Schema<(Bool, Bool)>,
        Never,
        Never
      >
    {
      let inputSchema = SchemaCoding.Support.parameterClauseSchema {
        SchemaCoding.Support.parameter(
          label: "bar",
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
        SchemaCoding.Support.parameter(
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
      }
      let outputSchema = SchemaCoding.Support.parameterClauseSchema {
        SchemaCoding.Support.parameter(
          label: "a",
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
        SchemaCoding.Support.parameter(
          label: "b",
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        )
      }
      return SchemaCoding.Support.CallableSchema(
        name: "fooAsync(bar:_:)",
        inputSchema: inputSchema,
        outputSchema: outputSchema,
        invoke: fooAsync(bar:_:)
      )
    }
  }

}
