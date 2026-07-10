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
        #"{"description":"Does math","properties":{"add":{"properties":{"amount":{"type":"integer"}},"required":["amount"]},"fetch":{"description":"Fetches an item","properties":{"id":{"type":"integer"}},"required":["id"]},"parity":{"properties":{"of":{"type":"integer"}},"required":["of"]}},"maxProperties":1}"#
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

  /// A single action's input schema is the tool's schema, with the tool
  /// description prepended.
  @Test
  func singleActionToolUsesActionInputSchema() throws {
    try test(
      Doubler.definition.inputSchema,
      encodesAs: #"{"description":"Doubles numbers","type":"integer"}"#
    )
  }

  @Test
  func singleActionInvokeTakesInputDirectly() async throws {
    let result = try await Doubler.definition.invoke(on: Doubler(), inputJSON: "21")
    #expect(result == "42")
  }

  @Test
  func nameArgumentOverridesTypeName() {
    #expect(Renamed.definition.name == "custom-name")
  }

  /// Actor methods are isolated to the callee: the sidecars force the async
  /// path, and invocations hop to the actor (observable through the
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

private struct ParityError: Error {}
