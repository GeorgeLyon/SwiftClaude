import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@SchemaCallable")
struct SchemaCallableMacroTests {

  @Test
  func testBasicSyncFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func foo(bar: Bool, _ baz: Bool) -> (a: Bool, b: Bool) {
        (!bar, !baz)
      }
      """,
      expandedSource: #####"""
        func foo(bar: Bool, _ baz: Bool) -> (a: Bool, b: Bool) {
          (!bar, !baz)
        }

        static func __schema__foo(bar: Bool.Type = Bool.self, _ baz: Bool.Type = Bool.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<(Bool, Bool)>, some SchemaCoding.Schema<(Bool, Bool)>, (Bool, Bool), Never> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "bar",
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "a",
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
            SchemaCoding.Support.parameter(
              label: "b",
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "foo(bar:_:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: foo(bar:_:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testAsyncFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func asyncFoo(value: String) async -> String {
        value
      }
      """,
      expandedSource: #####"""
        func asyncFoo(value: String) async -> String {
          value
        }

        static func __schema__asyncFoo(value: String.Type = String.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<String>, some SchemaCoding.Schema<String >, Never, Never> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "value",
              schema: SchemaCoding.Support.schema(
                representing: String.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: String.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "asyncFoo(value:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: asyncFoo(value:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testThrowingFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func throwingFoo(value: Int) throws -> Int {
        value
      }
      """,
      expandedSource: #####"""
        func throwingFoo(value: Int) throws -> Int {
          value
        }

        static func __schema__throwingFoo(value: Int.Type = Int.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<Int>, some SchemaCoding.Schema<Int >, Int, any Error> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "value",
              schema: SchemaCoding.Support.schema(
                representing: Int.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: Int.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "throwingFoo(value:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: throwingFoo(value:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testAsyncThrowingFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func asyncThrowingFoo(x: Double) async throws -> Double {
        x
      }
      """,
      expandedSource: #####"""
        func asyncThrowingFoo(x: Double) async throws -> Double {
          x
        }

        static func __schema__asyncThrowingFoo(x: Double.Type = Double.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<Double>, some SchemaCoding.Schema<Double >, Never, any Error> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "x",
              schema: SchemaCoding.Support.schema(
                representing: Double.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: Double.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "asyncThrowingFoo(x:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: asyncThrowingFoo(x:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testTypedThrowingFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func typedThrowingFoo(value: Bool) throws(MyError) -> Bool {
        value
      }
      """,
      expandedSource: #####"""
        func typedThrowingFoo(value: Bool) throws(MyError) -> Bool {
          value
        }

        static func __schema__typedThrowingFoo(value: Bool.Type = Bool.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<Bool>, some SchemaCoding.Schema<Bool >, Bool, MyError> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "value",
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "typedThrowingFoo(value:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: typedThrowingFoo(value:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testStaticFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      static func staticFoo(a: Int, b: Int) -> Int {
        a + b
      }
      """,
      expandedSource: #####"""
        static func staticFoo(a: Int, b: Int) -> Int {
          a + b
        }

        static func __schema__staticFoo(a: Int.Type = Int.self, b: Int.Type = Int.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<(Int, Int)>, some SchemaCoding.Schema<Int >, (Int, Int), Never> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "a",
              schema: SchemaCoding.Support.schema(
                representing: Int.self
              )
            )
            SchemaCoding.Support.parameter(
              label: "b",
              schema: SchemaCoding.Support.schema(
                representing: Int.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: Int.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "staticFoo(a:b:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: staticFoo(a:b:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testVoidReturnFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func voidFoo(message: String) {
        print(message)
      }
      """,
      expandedSource: #####"""
        func voidFoo(message: String) {
          print(message)
        }

        static func __schema__voidFoo(message: String.Type = String.self) -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<String>, some SchemaCoding.Schema<Void>, String, Never> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              label: "message",
              schema: SchemaCoding.Support.schema(
                representing: String.self
              )
            )
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
          }
          return SchemaCoding.Support.CallableSchema(
            name: "voidFoo(message:)",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: voidFoo(message:)
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testNoParameterFunction() {
    assertMacroExpansion(
      """
      @SchemaCallable
      func noParamFoo() -> Bool {
        true
      }
      """,
      expandedSource: #####"""
        func noParamFoo() -> Bool {
          true
        }

        static func __schema__noParamFoo() -> SchemaCoding.Support.CallableSchema<Void, some SchemaCoding.Schema<Void>, some SchemaCoding.Schema<Bool >, Void, Never> {
          let inputSchema = SchemaCoding.Support.parameterClauseSchema {
          }
          let outputSchema = SchemaCoding.Support.parameterClauseSchema {
            SchemaCoding.Support.parameter(
              schema: SchemaCoding.Support.schema(
                representing: Bool.self
              )
            )
          }
          return SchemaCoding.Support.CallableSchema(
            name: "noParamFoo()",
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            invoke: noParamFoo()
          )
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  private let macroSpecs = [
    "SchemaCallable": MacroSpec(type: SchemaCallableMacro.self)
  ]
}
