import SwiftDiagnostics
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredTool` lowers each `@StructuredAction` function's
/// parameter clause and return type onto `StructuredCodable` Input/Output
/// representations — using the same collapse rules as enum-case associated
/// values — generated as an inline `StructuredAction` in the `definition`
/// member. The synthesized type names fold in the full signature so overloads
/// of the same base name never collide.
@Suite
struct StructuredActionTests {

  /// The representative shape: a mixed-label parameter clause (`StructuredTuple`
  /// input), an all-labeled tuple return (synthesized object output), and an
  /// untyped `throws` (`any Error` failure) on an instance method.
  @Test
  func instanceMethodMixedTupleInputObjectOutputThrows() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "foo",
                failure: (any Error).self,
                invoke: { (callee: S, input: StructuredCoding.StructuredTuple<Bool, Bool>) throws -> __macro_local_45foo_bar_Bool___Bool__a__Bool__b__Bool__OutputfMu_ in
                  let output = try callee.foo(bar: input.values.0, input.values.1)
                  return __macro_local_45foo_bar_Bool___Bool__a__Bool__b__Bool__OutputfMu_(a: output.0, b: output.1)
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction
        func ping() {
        }
      }
      """,
      #"""
      struct S {
        func ping() {
        }

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "ping",
                failure: Never.self,
                invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                  callee.ping()
                  return StructuredCoding.StructuredEmptyObject()
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "echo",
                failure: Never.self,
                invoke: { (callee: S, input: String) -> String in
                  callee.echo(input)
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "greet",
                failure: Never.self,
                invoke: { (callee: S, input: __macro_local_30greet_name_String_String_InputfMu_) -> String in
                  callee.greet(name: input.name)
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "greet",
                failure: Never.self,
                invoke: { (callee: S, input: __macro_local_30greet_name_String_String_InputfMu_) -> String in
                  callee.greet(name: input.name)
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "pair",
                failure: Never.self,
                invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredTuple<Int, String> in
                  let output = callee.pair()
                  return StructuredCoding.StructuredTuple(output.0, output.1)
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "fetch",
                failure: FetchError.self,
                invoke: { (callee: S, input: __macro_local_31fetch_id_Int_String_async_InputfMu_) async throws(FetchError) -> String in
                  try await callee.fetch(id: input.id)
                }
              )
            )
          )
        }
      }
      """#
    )
  }

  /// An actor's instance method is isolated to its callee: the glue closure
  /// must hop to the actor, so it is forced async and `SyncInput` pinned to
  /// `Never` even though the function itself is synchronous.
  @Test
  func actorMethodForcesAsyncGlue() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      actor A {
        @StructuredAction
        func bump(_ value: Int) -> Int {
          value + 1
        }
      }
      """,
      #"""
      actor A {
        func bump(_ value: Int) -> Int {
          value + 1
        }

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<A> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "bump",
                failure: Never.self,
                invoke: { (callee: A, input: Int) async -> Int in
                  await callee.bump(input)
                }
              )
            )
          )
        }
      }
      """#
    )
  }

  /// `nonisolated` opts an actor method out of callee isolation, keeping the
  /// synchronous glue.
  @Test
  func nonisolatedActorMethodKeepsSyncGlue() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      actor A {
        @StructuredAction
        nonisolated func bump(_ value: Int) -> Int {
          value + 1
        }
      }
      """,
      #"""
      actor A {
        nonisolated func bump(_ value: Int) -> Int {
          value + 1
        }

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<A> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "bump",
                failure: Never.self,
                invoke: { (callee: A, input: Int) -> Int in
                  callee.bump(input)
                }
              )
            )
          )
        }
      }
      """#
    )
  }

  /// `public` on the tool and its actions propagates to the synthesized
  /// object and the definition.
  @Test
  func publicFunctionEmitsPublicPeers() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      public struct S {
        @StructuredAction
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

        public static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "run",
                failure: Never.self,
                invoke: { (callee: S, input: __macro_local_25run_name_String_Int_InputfMu_) -> Int in
                  callee.run(name: input.name)
                }
              )
            )
          )
        }
      }
      """#
    )
  }

  /// The attribute's `description`/`inputDescription`/`outputDescription`
  /// arguments are forwarded to the `StructuredAction` initializer.
  @Test
  func descriptionArgumentsFlowIntoInitializer() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction(description: "Adds numbers", inputDescription: "The addends", outputDescription: "The sum")
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "add",
                description: "Adds numbers",
                inputDescription: "The addends",
                outputDescription: "The sum",
                failure: Never.self,
                invoke: { (callee: S, input: __macro_local_25add_a_Int_b_Int_Int_InputfMu_) -> Int in
                  callee.add(a: input.a, b: input.b)
                }
              )
            )
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
      @StructuredTool
      struct S {
        @StructuredAction(keyConversionStrategy: .convertToSnakeCase)
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "set",
                failure: Never.self,
                invoke: { (callee: S, input: __macro_local_38set_userName_String_maxCount_Int_InputfMu_) -> StructuredCoding.StructuredEmptyObject in
                  callee.set(userName: input.userName, maxCount: input.maxCount)
                  return StructuredCoding.StructuredEmptyObject()
                }
              )
            )
          )
        }
      }
      """#
    )
  }

  // MARK: - Marker Diagnostics

  /// Actions must be members of a `@StructuredTool` type — a top-level
  /// function has no tool to belong to.
  @Test
  func rejectsTopLevelFunction() {
    assertStructuredCodableExpansion(
      """
      @StructuredAction
      func negate(_ value: Bool) -> Bool {
        !value
      }
      """,
      """
      func negate(_ value: Bool) -> Bool {
        !value
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@StructuredAction cannot be applied to top-level functions; actions must be members of a @StructuredTool type",
          line: 2, column: 6)
      ]
    )
  }

  /// A local function has no tool to belong to either.
  @Test
  func rejectsLocalFunction() {
    assertStructuredCodableExpansion(
      """
      func outer() {
        @StructuredAction
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
          message: "@StructuredAction cannot be applied to local functions",
          line: 3, column: 8)
      ]
    )
  }

  /// An extension's syntax cannot reveal whether the extended type is an
  /// actor — which decides the glue closure's isolation — so actions must be
  /// declared in the type's body.
  @Test
  func rejectsFunctionInExtension() {
    assertStructuredCodableExpansion(
      """
      extension S {
        @StructuredAction
        func echo(_ text: String) -> String {
          text
        }
      }
      """,
      """
      extension S {
        func echo(_ text: String) -> String {
          text
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@StructuredAction cannot be applied to functions in extensions; declare actions in the type's body",
          line: 3, column: 8)
      ]
    )
  }

  /// A marker on a type `@StructuredTool` never visits would silently do
  /// nothing.
  @Test
  func requiresStructuredToolOnEnclosingType() {
    assertStructuredCodableExpansion(
      """
      struct S {
        @StructuredAction
        func ping() {
        }
      }
      """,
      """
      struct S {
        func ping() {
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredAction requires the enclosing type to be marked @StructuredTool",
          line: 3, column: 8)
      ]
    )
  }

  /// The attribute only makes sense on functions.
  @Test
  func rejectsNonFunction() {
    assertStructuredCodableExpansion(
      """
      @StructuredAction
      struct S {
      }
      """,
      """
      struct S {
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredAction can only be applied to functions",
          line: 1, column: 1)
      ]
    )
  }

  // MARK: - Lowering Diagnostics

  /// `inout` (and other ownership specifiers) cannot be represented in a
  /// coded input.
  @Test
  func rejectsInoutParameter() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
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
          message: "@StructuredAction does not support `inout` parameters",
          line: 4, column: 10)
      ]
    )
  }

  /// Generic functions have no concrete Input/Output types to collapse onto.
  @Test
  func rejectsGenericFunction() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
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
          message: "@StructuredAction does not support generic functions",
          line: 4, column: 9)
      ]
    )
  }

  /// `rethrows` has no fixed failure type.
  @Test
  func rejectsRethrows() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
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
          message: "@StructuredAction does not support `rethrows`",
          line: 4, column: 37)
      ]
    )
  }

  /// Variadic parameters cannot be represented in a coded input.
  @Test
  func rejectsVariadicParameter() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
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
          message: "@StructuredAction does not support variadic parameters",
          line: 4, column: 12)
      ]
    )
  }

  /// A mutating method cannot be called on the by-value callee the glue
  /// closure receives.
  @Test
  func rejectsMutatingMethod() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
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
          message: "@StructuredAction does not support `mutating` methods",
          line: 4, column: 3)
      ]
    )
  }

  /// Defaults survive only in the all-labeled (object) collapse; elsewhere
  /// they are ignored with a warning, and expansion still proceeds.
  @Test
  func warnsOnUnrepresentableDefault() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
        func f(_ x: Int = 1) -> Int {
          x
        }
      }
      """,
      #"""
      struct S {
        func f(_ x: Int = 1) -> Int {
          x
        }

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "f",
                failure: Never.self,
                invoke: { (callee: S, input: Int) -> Int in
                  callee.f(input)
                }
              )
            )
          )
        }
      }
      """#,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Default value is ignored: only functions whose parameters are all labeled can encode defaults",
          line: 4, column: 21,
          severity: .warning)
      ]
    )
  }

}
