import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// End-to-end coverage for `@StructuredTool`: the generated `Definition`'s
/// stored actions value — its raw schema (single-action passthrough and
/// multi-action enumeration) across the input collapse shapes — plus typed
/// invocation through an actor-isolated callee. JSON dispatch is deliberately
/// absent: it returns in a later round, built on the typed
/// `invoke(on:with:)` overloads.
@Suite
struct StructuredToolIntegrationTests {

  /// The definition stores the tool's name — the type's name when the
  /// attribute provides none, emitted as a literal by the macro — and its
  /// description.
  @Test
  func toolExposesNameAndDescription() {
    #expect(Calculator.definition.name == "Calculator")
    #expect(Calculator.definition.description == "Does math")
  }

  /// Multiple actions synthesize the enumeration: a one-property object keyed
  /// by action name, each property carrying that action's input schema with
  /// the action description prepended.
  @Test
  func multiActionSchemaSynthesizesEnumeration() throws {
    try test(
      Calculator.definition.actions.inputSchema,
      encodesAs:
        #"{"properties":{"add":{"properties":{"amount":{"type":"integer"}},"required":["amount"]},"fetch":{"description":"Fetches an item","properties":{"id":{"type":"integer"}},"required":["id"]},"parity":{"properties":{"of":{"type":"integer"}},"required":["of"]}},"maxProperties":1}"#
    )
  }

  /// A single action's object input schema is the action's raw schema
  /// directly. The tool description is not folded in — it travels separately
  /// (`Greeter.definition.description`).
  @Test
  func singleActionToolUsesActionInputSchema() throws {
    try test(
      Greeter.definition.actions.inputSchema,
      encodesAs:
        #"{"properties":{"name":{"type":"string"}},"required":["name"]}"#
    )
  }

  /// A single action whose input is not an object (here a bare integer)
  /// publishes that raw schema unchanged; wrapping it for a wire format that
  /// requires top-level objects is the consumer's business (the Messages
  /// API's `ToolInputEnvelope`).
  @Test
  func scalarInputSchemaIsRaw() throws {
    try test(
      Doubler.definition.actions.inputSchema,
      encodesAs: #"{"type":"integer"}"#
    )
  }

  /// A single action whose input is an internally-tagged enumeration also
  /// publishes its raw schema: the style constrains every payload to an
  /// object, so each instance encodes as a JSON object (the discriminator
  /// alongside the case's properties) — which the input's
  /// `StructuredObjectRepresentable` marker records for consumers that
  /// constrain on it.
  @Test
  func singleActionInternallyTaggedInputSchemaIsRaw() throws {
    try test(
      Router.definition.actions.inputSchema,
      encodesAs:
        #"{"oneOf":[{"properties":{"kind":{"const":"set"},"value":{"type":"integer"}},"required":["kind","value"]},{"properties":{"kind":{"const":"reset"},"hard":{"type":"boolean"}},"required":["kind","hard"]}]}"#
    )
  }

  @Test
  func nameArgumentOverridesTypeName() {
    #expect(Renamed.definition.name == "custom-name")
    #expect(Renamed.definition.description == nil)
  }

  /// Actor methods are isolated to the callee: the generated glue forces the
  /// async path, and typed invocations hop to the actor (observable through
  /// the accumulated state). `definition` is a static, so it is nonisolated
  /// and readable synchronously from outside the actor.
  @Test
  func actorToolInvokesThroughIsolation() async throws {
    let counter = Counter()
    let actions = Counter.definition.actions

    let first = await actions.invoke(on: counter, with: 2)
    #expect(first == 2)

    let second = await actions.invoke(on: counter, with: 3)
    #expect(second == 5)
  }

}

// MARK: - Fixtures

/// `Calculator` pins the effect shapes the macro glue must keep compiling —
/// sync, async, and typed throws — alongside the multi-action enumeration
/// schema asserted above.
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

/// A single unlabeled-parameter action, so `Input` is a bare `Int` and the
/// typed `invoke(on:with:)` is callable from the test (a synthesized object
/// input's type is macro-local and unconstructible here).
@StructuredTool
private actor Counter {
  var count = 0

  @StructuredAction
  func increment(_ amount: Int) -> Int {
    count += amount
    return count
  }
}

private struct ParityError: Error {}
