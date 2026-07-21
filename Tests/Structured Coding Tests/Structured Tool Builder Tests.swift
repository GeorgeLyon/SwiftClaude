import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Coverage for hand-written (macro-free) tools built with
/// `StructuredAction.build`: the identity build keeping a lone action a leaf
/// `StructuredAction`, and the fold of a second action into a composed
/// `StructuredAction` at its placeholder instantiation. The
/// fixtures follow the same shape the macro generates — a nested
/// `Definition` storing the name, description, and an `actions` value whose
/// concrete type its initializer infers, plus a computed
/// `static var definition` — because that concrete inferred shape is what
/// consumers classify tools by.
///
/// Invocation here is typed — `invoke(on:with:)` on the leaf, or on a
/// group's stored `actions` tuple elements; JSON dispatch returns in a later
/// round.
///
/// The builder's folding overloads `precondition` that action names are
/// unique — a composed enumeration is keyed by name, so duplicates cannot
/// be represented. That path traps rather than throws (macro-generated
/// tools diagnose duplicates at expansion; the precondition guards
/// hand-written builders like these), so it is documented here rather than
/// crash-tested.
@Suite
struct StructuredToolBuilderTests {

  /// The definition stores name and description; a tool with no description
  /// witnesses the requirement with a stored `nil`.
  @Test
  func handWrittenToolExposesNameAndDescription() {
    #expect(Toolbox.definition.name == "toolbox")
    #expect(Toolbox.definition.description == "A toolbox")
    #expect(Doubler.definition.name == "Doubler")
    #expect(Doubler.definition.description == nil)
  }

  /// Two actions fold into a composed action: the enumeration schema keys
  /// each action by name, folding the action descriptions into the keyed
  /// properties.
  @Test
  func twoActionBuilderSynthesizesEnumeration() throws {
    try test(
      Toolbox.definition.actions.inputSchema,
      encodesAs:
        #"{"properties":{"double":{"type":"integer"},"shout":{"description":"Uppercases text","type":"string"}},"maxProperties":1}"#
    )
  }

  /// Composition yields a plain `StructuredAction` at the placeholder
  /// instantiation — the compile-time shape consumers classify on (the
  /// `let` binding is the type assertion; per-component type identity is
  /// gone by design, the stored schema is the identity). A composed action
  /// is pure schema: it carries no name or description of its own.
  @Test
  func compositionProducesPlaceholderInstantiation() {
    let actions:
      StructuredAction<
        Toolbox, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
      > = Toolbox.definition.actions
    #expect(actions.description == nil)
  }

  /// A standalone leaf keeps the typed invoke surface a future dispatch
  /// round will select into by name (the composed action no longer exposes
  /// its component leaves).
  @Test
  func standaloneLeafInvokesTyped() {
    let double = StructuredAction(
      name: "double",
      invoke: { (toolbox: Toolbox, value: Int) in value * 2 + toolbox.base }
    )
    #expect(double.name == "double")
    #expect(double.invoke(on: Toolbox(base: 1), with: 21) == 43)
  }

  /// A single action is the identity build: `actions` is the leaf action
  /// itself, and its object input schema is the action's raw schema — no
  /// envelope, no enumeration.
  @Test
  func singleObjectActionBuilderUsesActionInputSchemaDirectly() throws {
    try test(
      Greeter.definition.actions.inputSchema,
      encodesAs:
        #"{"properties":{"name":{"type":"string"}},"required":["name"]}"#
    )
  }

  @Test
  func singleObjectActionBuilderInvokesWithTypedInput() {
    let result = Greeter.definition.actions.invoke(
      on: Greeter(), with: GreetingInput(name: "moon"))
    #expect(result == "Hello, moon")
  }

  /// A hand-written scalar-input action publishes its raw schema — wrapping
  /// it for a wire format that requires top-level objects is the consumer's
  /// business — and invokes with the bare typed input.
  @Test
  func singleScalarActionBuilderStaysRaw() throws {
    try test(
      Doubler.definition.actions.inputSchema,
      encodesAs: #"{"type":"integer"}"#
    )
    #expect(Doubler.definition.actions.invoke(on: Doubler(), with: 21) == 42)
  }

}

// MARK: - Fixtures

@StructuredCodable
private struct GreetingInput {
  var name: String
}

private struct Toolbox: StructuredToolProtocol {

  var base: Int

  struct Definition: StructuredToolDefinitionProtocol {
    typealias Callee = Toolbox
    let name = "toolbox"
    let description: String? = "A toolbox"
    let actions = StructuredAction.build {
      StructuredAction(
        name: "double",
        invoke: { (toolbox: Toolbox, value: Int) in value * 2 + toolbox.base }
      )
      StructuredAction(
        name: "shout",
        description: "Uppercases text",
        invoke: { (_: Toolbox, text: String) in text.uppercased() }
      )
    }
  }

  static var definition: Definition { Definition() }

}

private struct Greeter: StructuredToolProtocol {

  struct Definition: StructuredToolDefinitionProtocol {
    typealias Callee = Greeter
    let name = "Greeter"
    let description: String? = nil
    let actions = StructuredAction.build {
      StructuredAction(
        name: "greet",
        invoke: { (_: Greeter, input: GreetingInput) in "Hello, \(input.name)" }
      )
    }
  }

  static var definition: Definition { Definition() }

}

private struct Doubler: StructuredToolProtocol {

  struct Definition: StructuredToolDefinitionProtocol {
    typealias Callee = Doubler
    let name = "Doubler"
    let description: String? = nil
    let actions = StructuredAction.build {
      StructuredAction(
        name: "double",
        invoke: { (_: Doubler, value: Int) in value * 2 }
      )
    }
  }

  static var definition: Definition { Definition() }

}
