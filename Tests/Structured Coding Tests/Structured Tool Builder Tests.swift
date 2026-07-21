import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Coverage for hand-written (macro-free) tools built with
/// `StructuredAction.build`: the identity build keeping a lone action a leaf
/// `StructuredAction`, and the fold of further actions into a composed
/// `StructuredAction` whose input nests `StructuredActionSelection`, whose
/// output collapses when shared or nests `StructuredActionResult` when the
/// types differ, whose sync-ness survives all-synchronous folds, and whose
/// failure stays `Never` for non-throwing components but collapses to
/// `any Error` once any component throws. The
/// fixtures follow the same shape the macro generates — a nested
/// `Definition` storing the name, description, and an `actions` value whose
/// concrete type its initializer infers, plus a computed
/// `static var definition` — because that concrete inferred shape is what
/// consumers classify tools by.
///
/// Invocation is typed throughout — `invoke(on:with:)` on a leaf, or on a
/// composed action with a selection value like `.first(.next(input))`;
/// nothing is erased, so composed dispatch is a `switch`, not a name
/// lookup. JSON dispatch returns in a later round.
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

  /// Composition yields a composed `StructuredAction` — structurally a
  /// single action with an enum argument. Nothing is erased: the input is
  /// the concrete `StructuredActionSelection` over the components' input
  /// types, and Toolbox's differing output types (`Int` vs `String`) nest
  /// into a `StructuredActionResult` (the `let` binding is the type
  /// assertion). Both components are synchronous and non-throwing, so
  /// `SyncInput` is the selection itself and `Failure` stays `Never`. A
  /// composed action carries no name or description of its own — a tool's
  /// name lives on its definition.
  @Test
  func compositionProducesComposedAction() {
    let actions:
      StructuredAction<
        Toolbox,
        StructuredActionSelection<Int, String>,
        StructuredActionResult<Int, String>,
        StructuredActionSelection<Int, String>,
        Never
      > = Toolbox.definition.actions
    #expect(actions.inputSchema.wrapped.propertyNames == ["double", "shout"])
    #expect(actions.name == "")
    #expect(actions.description == nil)
  }

  /// A mismatched-output fold stores the `oneOf` of the components' output
  /// schemas — a result is untagged on the wire (matching-output components
  /// collapse, so a payload can't be keyed by the action that produced it).
  @Test
  func mismatchedOutputsSynthesizeOneOfSchema() throws {
    try test(
      Toolbox.definition.actions.outputSchema,
      encodesAs: #"{"oneOf":[{"type":"integer"},{"type":"string"}]}"#
    )
  }

  /// Composed invoke is real and fully typed: a selection value picks the
  /// component by case (not by name), and Toolbox's differing outputs come
  /// back wrapped in the matching result case. Both components are
  /// synchronous and non-throwing, so the synchronous invoke dispatches
  /// with no `try` (in a synchronous context — an async context resolves
  /// `invoke(on:with:)` to the async surface, which
  /// `syncCompositionAlsoInvokesAsync` covers).
  @Test
  func composedActionInvokesTyped() {
    let actions = Toolbox.definition.actions
    let doubled = actions.invoke(on: Toolbox(base: 1), with: .first(21))
    guard case .first(let value) = doubled else {
      Issue.record("expected .first, got \(doubled)")
      return
    }
    #expect(value == 43)
    let shouted = actions.invoke(on: Toolbox(base: 0), with: .next("quiet"))
    guard case .next(let text) = shouted else {
      Issue.record("expected .next, got \(shouted)")
      return
    }
    #expect(text == "QUIET")
  }

  /// A synchronous composition's async invoke surface dispatches too — the
  /// fold wires both stored invokes.
  @Test
  func syncCompositionAlsoInvokesAsync() async {
    let shouted = await Toolbox.definition.actions.invoke(
      on: Toolbox(base: 0), with: .next("quiet"))
    guard case .next(let text) = shouted else {
      Issue.record("expected .next, got \(shouted)")
      return
    }
    #expect(text == "QUIET")
  }

  /// When every component agrees on an output type, the composition
  /// collapses to it — no `StructuredActionResult` appears, and invoking
  /// returns the shared type directly. All-synchronous components keep the
  /// composition synchronous (`SyncInput` is the nested selection).
  @Test
  func sharedOutputsCollapse() {
    let composed:
      StructuredAction<
        Toolbox,
        StructuredActionSelection<StructuredActionSelection<Int, Int>, Int>,
        Int,
        StructuredActionSelection<StructuredActionSelection<Int, Int>, Int>,
        Never
      > = StructuredAction.build {
        StructuredAction(
          name: "double",
          invoke: { (toolbox: Toolbox, value: Int) in value * 2 + toolbox.base }
        )
        StructuredAction(
          name: "increment",
          invoke: { (_: Toolbox, value: Int) in value + 1 }
        )
        StructuredAction(
          name: "negate",
          invoke: { (_: Toolbox, value: Int) in -value }
        )
      }
    #expect(composed.inputSchema.wrapped.propertyNames == ["double", "increment", "negate"])
    let doubled = composed.invoke(on: Toolbox(base: 1), with: .first(.first(21)))
    #expect(doubled == 43)
    let incremented = composed.invoke(on: Toolbox(base: 0), with: .first(.next(41)))
    #expect(incremented == 42)
    let negated = composed.invoke(on: Toolbox(base: 0), with: .next(7))
    #expect(negated == -7)
  }

  /// One `async` component anywhere makes the whole composition
  /// async-only: `SyncInput` collapses to `Never` (the `let` binding is
  /// the type assertion) and only the async invoke dispatches.
  @Test
  func asyncComponentMakesCompositionAsync() async {
    let composed:
      StructuredAction<
        Toolbox,
        StructuredActionSelection<Int, Int>,
        Int,
        Never,
        Never
      > = StructuredAction.build {
        StructuredAction(
          name: "echo",
          invoke: { (_: Toolbox, value: Int) async in value }
        )
        StructuredAction(
          name: "increment",
          invoke: { (_: Toolbox, value: Int) in value + 1 }
        )
      }
    let echoed = await composed.invoke(on: Toolbox(base: 0), with: .first(1))
    #expect(echoed == 1)
    let incremented = await composed.invoke(on: Toolbox(base: 0), with: .next(1))
    #expect(incremented == 2)
  }

  /// One throwing component collapses the composition's failure to
  /// `any Error` — the typed error propagates through the composed invoke
  /// unwrapped, whatever the other components throw (or don't).
  @Test
  func failuresCollapseToAnyError() {
    let composed:
      StructuredAction<
        Toolbox,
        StructuredActionSelection<String, Int>,
        StructuredActionResult<String, Int>,
        StructuredActionSelection<String, Int>,
        any Error
      > = StructuredAction.build {
        StructuredAction(
          name: "shout",
          invoke: { (_: Toolbox, text: String) throws(ShoutError) -> String in
            guard !text.isEmpty else { throw ShoutError.nothingToShout }
            return text.uppercased()
          }
        )
        StructuredAction(
          name: "double",
          invoke: { (_: Toolbox, value: Int) in value * 2 }
        )
      }
    do {
      _ = try composed.invoke(on: Toolbox(base: 0), with: .first(""))
      Issue.record("expected a throw")
    } catch {
      guard case ShoutError.nothingToShout = error else {
        Issue.record("unexpected error \(error)")
        return
      }
    }
  }

  /// A result encodes untagged: the selected component's bare output.
  @Test
  func resultEncodesUntagged() throws {
    try test(StructuredActionResult<Int, String>.first(7), encodesAs: "7")
    try test(StructuredActionResult<Int, String>.next("up"), encodesAs: #""up""#)
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

private enum ShoutError: Error {
  case nothingToShout
}

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
