import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// End-to-end coverage for `@StructuredTool`: the gathered definition's
/// reified schema (single-action passthrough and multi-action enumeration)
/// and JSON-in/JSON-out dispatch across every effect shape, including
/// actor-isolated callees.
@Suite
struct StructuredToolIntegrationTests {

  @Test
  func definitionExposesNameAndDescription() {
    let definition = Calculator.definition
    #expect(definition.name == "Calculator")
    #expect(definition.description == "Does math")
  }

  /// Multiple actions synthesize the enumeration: a one-property object keyed
  /// by action name, each property carrying that action's input schema with
  /// the action description prepended.
  @Test
  func multiActionSchemaSynthesizesEnumeration() throws {
    try test(
      Calculator.definition.inputSchema,
      encodesAs:
        #"{"properties":{"add":{"properties":{"amount":{"type":"integer"}},"required":["amount"]},"fetch":{"description":"Fetches an item","properties":{"id":{"type":"integer"}},"required":["id"]},"parity":{"properties":{"of":{"type":"integer"}},"required":["of"]}},"maxProperties":1}"#
    )
  }

  @Test
  func multiActionInvokeDispatchesByName() async throws {
    let callee = Calculator(base: 2)

    let sum = try await Calculator.definition.invoke(
      on: callee, inputJSON: #"{"add": {"amount": 3}}"#)
    #expect(sum == "5")

    let item = try await Calculator.definition.invoke(
      on: callee, inputJSON: #"{"fetch": {"id": 7}}"#)
    #expect(item == #""item-7""#)

    let even = try await Calculator.definition.invoke(
      on: callee, inputJSON: #"{"parity": {"of": 4}}"#)
    #expect(even == "true")
  }

  @Test
  func typedActionErrorPropagates() async throws {
    await #expect(throws: ParityError.self) {
      _ = try await Calculator.definition.invoke(
        on: Calculator(base: 0), inputJSON: #"{"parity": {"of": -1}}"#)
    }
  }

  @Test
  func invalidInvocationsThrow() async throws {
    let callee = Calculator(base: 0)

    // Unknown action name.
    await #expect(throws: StructuredToolInvocationError.self) {
      _ = try await Calculator.definition.invoke(
        on: callee, inputJSON: #"{"missing": {}}"#)
    }

    // No action selected.
    await #expect(throws: StructuredToolInvocationError.self) {
      _ = try await Calculator.definition.invoke(on: callee, inputJSON: "{}")
    }

    // More than one action selected.
    await #expect(throws: StructuredToolInvocationError.self) {
      _ = try await Calculator.definition.invoke(
        on: callee, inputJSON: #"{"add": {"amount": 1}, "fetch": {"id": 1}}"#)
    }
  }

  /// A single action's object input schema is the tool's schema directly.
  /// The tool description is not folded in — it travels separately, in the
  /// definition's `description`.
  @Test
  func singleActionToolUsesActionInputSchema() throws {
    try test(
      Greeter.definition.inputSchema,
      encodesAs:
        #"{"properties":{"name":{"type":"string"}},"required":["name"]}"#
    )
  }

  @Test
  func singleActionInvokeTakesObjectInputDirectly() async throws {
    let result = try await Greeter.definition.invoke(
      on: Greeter(), inputJSON: #"{"name": "moon"}"#)
    #expect(result == #""Hello, moon""#)
  }

  // MARK: - Input Envelope

  /// A single action whose input schema is not an object (here a bare
  /// integer) gets enveloped in an object with one required `"input"`
  /// property — the Anthropic API requires tool input schemas to be
  /// top-level objects.
  @Test
  func singleActionScalarInputSchemaIsEnveloped() throws {
    try test(
      Doubler.definition.inputSchema,
      encodesAs:
        #"{"properties":{"input":{"type":"integer"}},"required":["input"]}"#
    )
  }

  @Test
  func singleActionScalarInvokeDecodesInputEnvelope() async throws {
    let result = try await Doubler.definition.invoke(
      on: Doubler(), inputJSON: #"{"input": 21}"#)
    #expect(result == "42")
  }

  /// Mixed-label tuples collapse to a tuple schema (`prefixItems`), which is
  /// enveloped the same way scalars are.
  @Test
  func singleActionTupleInvokeDecodesInputEnvelope() async throws {
    let result = try await Flipper.definition.invoke(
      on: Flipper(), inputJSON: #"{"input": [true, false]}"#)
    #expect(result == #"{"a":false,"b":true}"#)
  }

  @Test
  func invalidInputEnvelopesThrow() async throws {
    // Bare value where the envelope is expected.
    await #expect(throws: (any Error).self) {
      _ = try await Doubler.definition.invoke(on: Doubler(), inputJSON: "21")
    }

    // Empty envelope.
    await #expect(throws: StructuredToolInvocationError.self) {
      _ = try await Doubler.definition.invoke(on: Doubler(), inputJSON: "{}")
    }

    // Wrong property name.
    await #expect(throws: StructuredToolInvocationError.self) {
      _ = try await Doubler.definition.invoke(on: Doubler(), inputJSON: #"{"value": 21}"#)
    }

    // More than one property.
    await #expect(throws: StructuredToolInvocationError.self) {
      _ = try await Doubler.definition.invoke(
        on: Doubler(), inputJSON: #"{"input": 21, "extra": 1}"#)
    }
  }

  /// A single action whose input is an internally-tagged enumeration is not
  /// enveloped: the style constrains every payload to an object, so each
  /// instance encodes as a JSON object (the discriminator alongside the
  /// case's properties) and the `oneOf` schema stands as the tool's input
  /// schema directly.
  @Test
  func singleActionInternallyTaggedInputIsNotEnveloped() throws {
    try test(
      Router.definition.inputSchema,
      encodesAs:
        #"{"oneOf":[{"properties":{"kind":{"const":"set"},"value":{"type":"integer"}},"required":["kind","value"]},{"properties":{"kind":{"const":"reset"},"hard":{"type":"boolean"}},"required":["kind","hard"]}]}"#
    )
  }

  @Test
  func singleActionInternallyTaggedInvokeTakesInputDirectly() async throws {
    let set = try await Router.definition.invoke(
      on: Router(), inputJSON: #"{"kind": "set", "value": 3}"#)
    #expect(set == #""set 3""#)

    let reset = try await Router.definition.invoke(
      on: Router(), inputJSON: #"{"kind": "reset", "hard": true}"#)
    #expect(reset == #""reset hard""#)
  }

  @Test
  func nameArgumentOverridesTypeName() {
    #expect(Renamed.definition.name == "custom-name")
  }

  /// Actor methods are isolated to the callee: the generated glue forces the
  /// async path, and invocations hop to the actor (observable through the
  /// accumulated state).
  @Test
  func actorToolInvokesThroughIsolation() async throws {
    let counter = Counter()

    let first = try await Counter.definition.invoke(
      on: counter, inputJSON: #"{"increment": {"by": 2}}"#)
    #expect(first == "2")

    let second = try await Counter.definition.invoke(
      on: counter, inputJSON: #"{"increment": {"by": 3}}"#)
    #expect(second == "5")

    let described = try await Counter.definition.invoke(
      on: counter, inputJSON: #"{"describe": {}}"#)
    #expect(described == #""counted 5""#)
  }

  // MARK: - Collapse Shapes

  /// The remaining input/output collapse shapes, exercised end to end through
  /// dispatch: mixed-label tuples, void, defaulted parameters, optionals, and
  /// untyped throws.
  @Test
  func mixedTupleInputObjectOutputRoundTrips() async throws {
    let result = try await Shapes.definition.invoke(
      on: Shapes(), inputJSON: #"{"flip": [true, false]}"#)
    #expect(result == #"{"a":false,"b":true}"#)
  }

  @Test
  func voidOutputAndEmptyInputCodeAsEmptyObjects() async throws {
    let result = try await Shapes.definition.invoke(
      on: Shapes(), inputJSON: #"{"ping": {}}"#)
    #expect(result == "{}")
  }

  /// Defaults follow struct (`var x: T = expr`) semantics exactly: a
  /// non-optional defaulted parameter is still required in the JSON — the
  /// default seeds partial streaming, it does not make the key omittable.
  @Test
  func nonOptionalDefaultedParameterIsStillRequired() async throws {
    let supplied = try await Shapes.definition.invoke(
      on: Shapes(), inputJSON: #"{"greet": {"name": "moon"}}"#)
    #expect(supplied == #""Hello, moon""#)

    await #expect(throws: (any Error).self) {
      _ = try await Shapes.definition.invoke(on: Shapes(), inputJSON: #"{"greet": {}}"#)
    }
  }

  @Test
  func optionalDefaultedParameterMayBeOmitted() async throws {
    let result = try await Shapes.definition.invoke(
      on: Shapes(), inputJSON: #"{"log": {"message": "hi"}}"#)
    #expect(result == #""hi@none""#)
  }

  @Test
  func untypedThrowsPropagates() async throws {
    await #expect(throws: NoElementsError.self) {
      _ = try await Shapes.definition.invoke(on: Shapes(), inputJSON: #"{"head": []}"#)
    }
    let first = try await Shapes.definition.invoke(
      on: Shapes(), inputJSON: #"{"head": [3, 1]}"#)
    #expect(first == "3")
  }

}

// MARK: - Fixtures

@StructuredTool(description: "Does math")
private struct Calculator {
  var base: Int

  @StructuredAction
  func add(amount: Int) -> Int {
    base + amount
  }

  @StructuredAction(description: "Fetches an item")
  func fetch(id: Int) async -> String {
    "item-\(id)"
  }

  @StructuredAction
  func parity(of value: Int) throws(ParityError) -> Bool {
    guard value >= 0 else {
      throw ParityError()
    }
    return value.isMultiple(of: 2)
  }
}

@StructuredTool(description: "Doubles numbers")
private struct Doubler {
  @StructuredAction
  func double(_ value: Int) -> Int {
    value * 2
  }
}

@StructuredTool(description: "Greets people")
private struct Greeter {
  @StructuredAction
  func greet(name: String) -> String {
    "Hello, \(name)"
  }
}

@StructuredTool
private struct Flipper {
  @StructuredAction
  func flip(bar: Bool, _ baz: Bool) -> (a: Bool, b: Bool) {
    (baz, bar)
  }
}

@StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "kind"))
private enum RouterCommand {
  case set(value: Int)
  case reset(hard: Bool)
}

@StructuredTool
private struct Router {
  @StructuredAction
  func route(_ command: RouterCommand) -> String {
    switch command {
    case .set(let value):
      "set \(value)"
    case .reset(let hard):
      hard ? "reset hard" : "reset soft"
    }
  }
}

@StructuredTool(name: "custom-name")
private struct Renamed {
  @StructuredAction
  func noop() {
  }
}

@StructuredTool
private actor Counter {
  var count = 0

  @StructuredAction
  func increment(by amount: Int) -> Int {
    count += amount
    return count
  }

  @StructuredAction
  func describe() -> String {
    "counted \(count)"
  }
}

@StructuredTool
private struct Shapes {
  @StructuredAction
  func flip(bar: Bool, _ baz: Bool) throws -> (a: Bool, b: Bool) {
    (baz, bar)
  }

  @StructuredAction
  func ping() {
  }

  @StructuredAction
  func greet(name: String = "world") -> String {
    "Hello, \(name)"
  }

  @StructuredAction
  func log(message: String, level: Int? = nil) -> String {
    "\(message)@\(level.map(String.init) ?? "none")"
  }

  @StructuredAction
  func head(_ values: [Int]) throws -> Int {
    guard let first = values.first else {
      throw NoElementsError()
    }
    return first
  }
}

private struct ParityError: Error {}
private struct NoElementsError: Error {}
