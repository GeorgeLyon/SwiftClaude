import SwiftDiagnostics
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredCallable` lowers a function's parameter clause and
/// return type onto `StructuredCodable` Input/Output representations — using
/// the same collapse rules as enum-case associated values — tied together by a
/// `StructuredCallable` sidecar carrying the function's effects. The
/// synthesized type names fold in the full signature so overloads of the same
/// base name never collide.
@Suite
struct StructuredCallableTests {

  /// The representative shape: a mixed-label parameter clause (`StructuredTuple`
  /// input), an all-labeled tuple return (synthesized object output), and an
  /// untyped `throws` (`any Error` failure) on an instance method (`Self` callee).
  @Test
  func instanceMethodMixedTupleInputObjectOutputThrows() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func foo(bar: Bool, _ baz: Bool) throws -> (a: Bool, b: Bool) {
          (bar, baz)
        }
      }
      """,
      #"""
      struct S {
        func foo(bar: Bool, _ baz: Bool) throws -> (a: Bool, b: Bool) {
          (bar, baz)
        }

        struct __macro_local_45foo_bar_Bool___Bool__a__Bool__b__Bool__OutputfMu_: StructuredCoding.StructuredObject {
          var a: Bool
          var b: Bool
          typealias __macro_local_1afMu_ = StructuredCoding.StructuredObjectProperty<Self, Bool._StructuredObjectPropertyDefinition>
          typealias __macro_local_1bfMu_ = StructuredCoding.StructuredObjectProperty<Self, Bool._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = (__macro_local_1afMu_, __macro_local_1bfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_1afMu_(
                name: "a",
                keyPath: \.a,
                schema: __macro_local_1afMu_.Definition.CodingValue.schema
              ), __macro_local_1bfMu_(
                name: "b",
                keyPath: \.b,
                schema: __macro_local_1bfMu_.Definition.CodingValue.schema
              ))
          }
          typealias ObjectDecoderValues = (__macro_local_1afMu_.ObjectDecoderValue, __macro_local_1bfMu_.ObjectDecoderValue)
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              a: objectDecoder.values.0,
              b: objectDecoder.values.1
            )
          }
        }

        static func __structuredCallable_foo(bar: Bool.Type = Bool.self, _ baz: Bool.Type = Bool.self) -> StructuredCoding.StructuredCallable<Self, StructuredCoding.StructuredTuple<Bool, Bool>, __macro_local_45foo_bar_Bool___Bool__a__Bool__b__Bool__OutputfMu_, StructuredCoding.StructuredTuple<Bool, Bool>, any Error> {
          StructuredCoding.StructuredCallable(
            name: "foo(bar:_:)",
            invoke: { (callee, input) throws in
              let output = try callee.foo(bar: input.values.0, input.values.1)
              return __macro_local_45foo_bar_Bool___Bool__a__Bool__b__Bool__OutputfMu_(a: output.0, b: output.1)
            }
          )
        }
      }
      """#
    )
  }

  /// No parameters and no return: `StructuredEmptyObject` on both sides, and the
  /// glue discards the input and returns an empty object after the call.
  @Test
  func emptyParameterClauseVoidReturn() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func ping() {
        }
      }
      """,
      #"""
      struct S {
        func ping() {
        }

        static func __structuredCallable_ping() -> StructuredCoding.StructuredCallable<Self, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, Never> {
          StructuredCoding.StructuredCallable(
            name: "ping()",
            invoke: { (callee, _) in
              callee.ping()
              return StructuredCoding.StructuredEmptyObject()
            }
          )
        }
      }
      """#
    )
  }

  /// A single unlabeled parameter and a single return type are used directly —
  /// no synthesized wrapper on either side.
  @Test
  func singleUnlabeledParameterUsesBareTypes() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func echo(_ text: String) -> String {
          text
        }
      }
      """,
      #"""
      struct S {
        func echo(_ text: String) -> String {
          text
        }

        static func __structuredCallable_echo(_ text: String.Type = String.self) -> StructuredCoding.StructuredCallable<Self, String, String, String, Never> {
          StructuredCoding.StructuredCallable(
            name: "echo(_:)",
            invoke: { (callee, input) in
              callee.echo(input)
            }
          )
        }
      }
      """#
    )
  }

  /// A label names an object property, so a single labeled parameter synthesizes
  /// a one-property Input object, exactly like a labeled enum-case value.
  @Test
  func labeledSingleParameterSynthesizesInputObject() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func greet(name: String) -> String {
          name
        }
      }
      """,
      #"""
      struct S {
        func greet(name: String) -> String {
          name
        }

        struct __macro_local_30greet_name_String_String_InputfMu_: StructuredCoding.StructuredObject {
          var name: String
          typealias __macro_local_4namefMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = __macro_local_4namefMu_
          static func properties() -> StructuredObjectProperties {
            __macro_local_4namefMu_(
              name: "name",
              keyPath: \.name,
              schema: __macro_local_4namefMu_.Definition.CodingValue.schema
            )
          }
          typealias ObjectDecoderValues = __macro_local_4namefMu_.ObjectDecoderValue
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              name: objectDecoder.values
            )
          }
        }

        static func __structuredCallable_greet(name: String.Type = String.self) -> StructuredCoding.StructuredCallable<Self, __macro_local_30greet_name_String_String_InputfMu_, String, __macro_local_30greet_name_String_String_InputfMu_, Never> {
          StructuredCoding.StructuredCallable(
            name: "greet(name:)",
            invoke: { (callee, input) in
              callee.greet(name: input.name)
            }
          )
        }
      }
      """#
    )
  }

  /// A parameter default lowers like a `var x: T = expr` struct property: the
  /// `Mutable` definition wrapper plus a `?? default` decode fallback.
  @Test
  func defaultedParameterBecomesMutableDefault() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func greet(name: String = "world") -> String {
          name
        }
      }
      """,
      #"""
      struct S {
        func greet(name: String = "world") -> String {
          name
        }

        struct __macro_local_30greet_name_String_String_InputfMu_: StructuredCoding.StructuredObject {
          var name: String
          typealias __macro_local_4namefMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<String._StructuredObjectPropertyDefinition>>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = __macro_local_4namefMu_
          static func properties() -> StructuredObjectProperties {
            __macro_local_4namefMu_(
              name: "name",
              keyPath: \.name,
              schema: __macro_local_4namefMu_.Definition.CodingValue.schema
            )
          }
          typealias ObjectDecoderValues = __macro_local_4namefMu_.ObjectDecoderValue
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              name: objectDecoder.values ?? "world"
            )
          }
        }

        static func __structuredCallable_greet(name: String.Type = String.self) -> StructuredCoding.StructuredCallable<Self, __macro_local_30greet_name_String_String_InputfMu_, String, __macro_local_30greet_name_String_String_InputfMu_, Never> {
          StructuredCoding.StructuredCallable(
            name: "greet(name:)",
            invoke: { (callee, input) in
              callee.greet(name: input.name)
            }
          )
        }
      }
      """#
    )
  }

  /// An unlabeled tuple return collapses onto `StructuredTuple`, packed
  /// positionally from the raw result.
  @Test
  func unlabeledTupleReturnUsesStructuredTuple() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func pair() -> (Int, String) {
          (1, "one")
        }
      }
      """,
      #"""
      struct S {
        func pair() -> (Int, String) {
          (1, "one")
        }

        static func __structuredCallable_pair() -> StructuredCoding.StructuredCallable<Self, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredTuple<Int, String>, StructuredCoding.StructuredEmptyObject, Never> {
          StructuredCoding.StructuredCallable(
            name: "pair()",
            invoke: { (callee, _) in
              let output = callee.pair()
              return StructuredCoding.StructuredTuple(output.0, output.1)
            }
          )
        }
      }
      """#
    )
  }

  /// `async` pins `SyncInput` to `Never` (no synchronous invoke) and
  /// `throws(E)` carries the typed failure into the closure and generics.
  @Test
  func asyncTypedThrowsPinsSyncInputToNever() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func fetch(id: Int) async throws(FetchError) -> String {
          "x"
        }
      }
      """,
      #"""
      struct S {
        func fetch(id: Int) async throws(FetchError) -> String {
          "x"
        }

        struct __macro_local_31fetch_id_Int_String_async_InputfMu_: StructuredCoding.StructuredObject {
          var id: Int
          typealias __macro_local_2idfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = __macro_local_2idfMu_
          static func properties() -> StructuredObjectProperties {
            __macro_local_2idfMu_(
              name: "id",
              keyPath: \.id,
              schema: __macro_local_2idfMu_.Definition.CodingValue.schema
            )
          }
          typealias ObjectDecoderValues = __macro_local_2idfMu_.ObjectDecoderValue
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              id: objectDecoder.values
            )
          }
        }

        static func __structuredCallable_fetch(id: Int.Type = Int.self) -> StructuredCoding.StructuredCallable<Self, __macro_local_31fetch_id_Int_String_async_InputfMu_, String, Never, FetchError> {
          StructuredCoding.StructuredCallable(
            name: "fetch(id:)",
            invoke: { (callee, input) async throws(FetchError) in
              try await callee.fetch(id: input.id)
            }
          )
        }
      }
      """#
    )
  }

  /// A static method needs no callee: `Callee == Void`, and the glue calls the
  /// member unqualified from the static sidecar's scope.
  @Test
  func staticMethodHasVoidCallee() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        static func make(count: Int) -> Int {
          count
        }
      }
      """,
      #"""
      struct S {
        static func make(count: Int) -> Int {
          count
        }

        struct __macro_local_24make_count_Int_Int_InputfMu_: StructuredCoding.StructuredObject {
          var count: Int
          typealias __macro_local_5countfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = __macro_local_5countfMu_
          static func properties() -> StructuredObjectProperties {
            __macro_local_5countfMu_(
              name: "count",
              keyPath: \.count,
              schema: __macro_local_5countfMu_.Definition.CodingValue.schema
            )
          }
          typealias ObjectDecoderValues = __macro_local_5countfMu_.ObjectDecoderValue
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              count: objectDecoder.values
            )
          }
        }

        static func __structuredCallable_make(count: Int.Type = Int.self) -> StructuredCoding.StructuredCallable<Void, __macro_local_24make_count_Int_Int_InputfMu_, Int, __macro_local_24make_count_Int_Int_InputfMu_, Never> {
          StructuredCoding.StructuredCallable(
            name: "make(count:)",
            invoke: { (_, input) in
              make(count: input.count)
            }
          )
        }
      }
      """#
    )
  }

  /// A top-level function's sidecar is itself a top-level function — no
  /// `static` modifier.
  @Test
  func topLevelFunctionSidecarIsNotStatic() {
    assertStructuredCodableExpansion(
      """
      @StructuredCallable
      func negate(_ value: Bool) -> Bool {
        !value
      }
      """,
      #"""

      func negate(_ value: Bool) -> Bool {
        !value
      }

      func __structuredCallable_negate(_ value: Bool.Type = Bool.self) -> StructuredCoding.StructuredCallable<Void, Bool, Bool, Bool, Never> {
        StructuredCoding.StructuredCallable(
          name: "negate(_:)",
          invoke: { (_, input) in
            negate(input)
          }
        )
      }
      """#
    )
  }

  /// `public` on the decorated function propagates to the synthesized object
  /// and the sidecar.
  @Test
  func publicFunctionEmitsPublicPeers() {
    assertStructuredCodableExpansion(
      """
      public struct S {
        @StructuredCallable
        public func run(name: String) -> Int {
          name.count
        }
      }
      """,
      #"""
      public struct S {
        public func run(name: String) -> Int {
          name.count
        }

        public struct __macro_local_25run_name_String_Int_InputfMu_: StructuredCoding.StructuredObject {
          public var name: String
          public typealias __macro_local_4namefMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
          public static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          public typealias StructuredObjectProperties = __macro_local_4namefMu_
          public static func properties() -> StructuredObjectProperties {
            __macro_local_4namefMu_(
              name: "name",
              keyPath: \.name,
              schema: __macro_local_4namefMu_.Definition.CodingValue.schema
            )
          }
          public typealias ObjectDecoderValues = __macro_local_4namefMu_.ObjectDecoderValue
          public static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              name: objectDecoder.values
            )
          }
        }

        public static func __structuredCallable_run(name: String.Type = String.self) -> StructuredCoding.StructuredCallable<Self, __macro_local_25run_name_String_Int_InputfMu_, Int, __macro_local_25run_name_String_Int_InputfMu_, Never> {
          StructuredCoding.StructuredCallable(
            name: "run(name:)",
            invoke: { (callee, input) in
              callee.run(name: input.name)
            }
          )
        }
      }
      """#
    )
  }

  /// The attribute's `description`/`inputDescription`/`outputDescription`
  /// arguments are forwarded to the `StructuredCallable` initializer.
  @Test
  func descriptionArgumentsFlowIntoInitializer() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable(description: "Adds numbers", inputDescription: "The addends", outputDescription: "The sum")
        func add(a: Int, b: Int) -> Int {
          a + b
        }
      }
      """,
      #"""
      struct S {
        func add(a: Int, b: Int) -> Int {
          a + b
        }

        struct __macro_local_25add_a_Int_b_Int_Int_InputfMu_: StructuredCoding.StructuredObject {
          var a: Int
          var b: Int
          typealias __macro_local_1afMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
          typealias __macro_local_1bfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = (__macro_local_1afMu_, __macro_local_1bfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_1afMu_(
                name: "a",
                keyPath: \.a,
                schema: __macro_local_1afMu_.Definition.CodingValue.schema
              ), __macro_local_1bfMu_(
                name: "b",
                keyPath: \.b,
                schema: __macro_local_1bfMu_.Definition.CodingValue.schema
              ))
          }
          typealias ObjectDecoderValues = (__macro_local_1afMu_.ObjectDecoderValue, __macro_local_1bfMu_.ObjectDecoderValue)
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              a: objectDecoder.values.0,
              b: objectDecoder.values.1
            )
          }
        }

        static func __structuredCallable_add(a: Int.Type = Int.self, b: Int.Type = Int.self) -> StructuredCoding.StructuredCallable<Self, __macro_local_25add_a_Int_b_Int_Int_InputfMu_, Int, __macro_local_25add_a_Int_b_Int_Int_InputfMu_, Never> {
          StructuredCoding.StructuredCallable(
            name: "add(a:b:)",
            description: "Adds numbers",
            inputDescription: "The addends",
            outputDescription: "The sum",
            invoke: { (callee, input) in
              callee.add(a: input.a, b: input.b)
            }
          )
        }
      }
      """#
    )
  }

  /// `keyConversionStrategy: .convertToSnakeCase` converts the synthesized
  /// object's JSON keys; the Swift property names are untouched.
  @Test
  func keyConversionStrategyConvertsJSONKeys() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable(keyConversionStrategy: .convertToSnakeCase)
        func set(userName: String, maxCount: Int) {
        }
      }
      """,
      #"""
      struct S {
        func set(userName: String, maxCount: Int) {
        }

        struct __macro_local_38set_userName_String_maxCount_Int_InputfMu_: StructuredCoding.StructuredObject {
          var userName: String
          var maxCount: Int
          typealias __macro_local_8userNamefMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
          typealias __macro_local_8maxCountfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = (__macro_local_8userNamefMu_, __macro_local_8maxCountfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_8userNamefMu_(
                name: "user_name",
                keyPath: \.userName,
                schema: __macro_local_8userNamefMu_.Definition.CodingValue.schema
              ), __macro_local_8maxCountfMu_(
                name: "max_count",
                keyPath: \.maxCount,
                schema: __macro_local_8maxCountfMu_.Definition.CodingValue.schema
              ))
          }
          typealias ObjectDecoderValues = (__macro_local_8userNamefMu_.ObjectDecoderValue, __macro_local_8maxCountfMu_.ObjectDecoderValue)
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              userName: objectDecoder.values.0,
              maxCount: objectDecoder.values.1
            )
          }
        }

        static func __structuredCallable_set(userName: String.Type = String.self, maxCount: Int.Type = Int.self) -> StructuredCoding.StructuredCallable<Self, __macro_local_38set_userName_String_maxCount_Int_InputfMu_, StructuredCoding.StructuredEmptyObject, __macro_local_38set_userName_String_maxCount_Int_InputfMu_, Never> {
          StructuredCoding.StructuredCallable(
            name: "set(userName:maxCount:)",
            invoke: { (callee, input) in
              callee.set(userName: input.userName, maxCount: input.maxCount)
              return StructuredCoding.StructuredEmptyObject()
            }
          )
        }
      }
      """#
    )
  }

  // MARK: - Diagnostics

  /// `inout` (and other ownership specifiers) cannot be represented in a
  /// coded input.
  @Test
  func rejectsInoutParameter() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func f(x: inout Int) {
        }
      }
      """,
      """
      struct S {
        func f(x: inout Int) {
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable does not support `inout` parameters",
          line: 3, column: 10)
      ]
    )
  }

  /// Generic functions have no concrete Input/Output types to collapse onto.
  @Test
  func rejectsGenericFunction() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func f<T>(x: T) -> T {
          x
        }
      }
      """,
      """
      struct S {
        func f<T>(x: T) -> T {
          x
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable does not support generic functions",
          line: 3, column: 9)
      ]
    )
  }

  /// `rethrows` has no fixed failure type.
  @Test
  func rejectsRethrows() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func f(_ body: () throws -> Void) rethrows {
          try body()
        }
      }
      """,
      """
      struct S {
        func f(_ body: () throws -> Void) rethrows {
          try body()
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable does not support `rethrows`",
          line: 3, column: 37)
      ]
    )
  }

  /// Variadic parameters cannot be represented in a coded input.
  @Test
  func rejectsVariadicParameter() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func sum(_ values: Int...) -> Int {
          0
        }
      }
      """,
      """
      struct S {
        func sum(_ values: Int...) -> Int {
          0
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable does not support variadic parameters",
          line: 3, column: 12)
      ]
    )
  }

  /// A mutating method cannot be called on the by-value callee the glue
  /// closure receives.
  @Test
  func rejectsMutatingMethod() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        mutating func bump() {
        }
      }
      """,
      """
      struct S {
        mutating func bump() {
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable does not support `mutating` methods",
          line: 3, column: 3)
      ]
    )
  }

  /// A local function's sidecar would itself be local — nothing can reach it.
  @Test
  func rejectsLocalFunction() {
    assertStructuredCodableExpansion(
      """
      func outer() {
        @StructuredCallable
        func inner() {
        }
      }
      """,
      """
      func outer() {
        func inner() {
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable cannot be applied to local functions",
          line: 3, column: 8)
      ]
    )
  }

  /// The attribute only makes sense on functions.
  @Test
  func rejectsNonFunction() {
    assertStructuredCodableExpansion(
      """
      @StructuredCallable
      struct S {
      }
      """,
      """
      struct S {
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredCallable can only be applied to functions",
          line: 1, column: 1)
      ]
    )
  }

  /// Defaults survive only in the all-labeled (object) collapse; elsewhere
  /// they are ignored with a warning, and expansion still proceeds.
  @Test
  func warnsOnUnrepresentableDefault() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredCallable
        func f(_ x: Int = 1) -> Int {
          x
        }
      }
      """,
      """
      struct S {
        func f(_ x: Int = 1) -> Int {
          x
        }

        static func __structuredCallable_f(_ x: Int.Type = Int.self) -> StructuredCoding.StructuredCallable<Self, Int, Int, Int, Never> {
          StructuredCoding.StructuredCallable(
            name: "f(_:)",
            invoke: { (callee, input) in
              callee.f(input)
            }
          )
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Default value is ignored: only functions whose parameters are all labeled can encode defaults",
          line: 3, column: 21,
          severity: .warning)
      ]
    )
  }

}
