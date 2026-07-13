import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Runtime-level coverage for `StructuredAction` values constructed directly,
/// without macros: initializer inference with no type context (the same
/// inference the generated inline actions rely on), every `invoke` overload,
/// and name/description/schema exposure.
@Suite
struct StructuredActionRuntimeTests {

  /// A synchronous non-throwing closure picks the sync initializer and infers
  /// `Failure == Never`, so `invoke` needs no `try`.
  @Test
  func syncActionInvokes() {
    let action = StructuredAction(
      name: "double",
      invoke: { (toolbox: Toolbox, value: Int) in value * (2 + toolbox.base) }
    )
    #expect(action.name == "double")
    #expect(action.description == nil)
    #expect(action.invoke(on: Toolbox(base: 0), with: 21) == 42)
  }

  /// `Callee == Void` initializers take a single-parameter closure and the
  /// callee-less `invoke` overloads apply.
  @Test
  func voidCalleeActionInvokes() {
    let action = StructuredAction(
      name: "negate",
      invoke: { (value: Bool) in !value }
    )
    #expect(action.invoke(with: true) == false)
  }

  @Test
  func asyncActionInvokes() async {
    let action = StructuredAction(
      name: "fetch",
      invoke: { (_: Toolbox, id: Int) async in "item-\(id)" }
    )
    let item = await action.invoke(on: Toolbox(base: 0), with: 7)
    #expect(item == "item-7")
  }

  /// `throws(E)` survives into the action: the `do throws(ParityError)`
  /// block only compiles because `Failure == ParityError`.
  @Test
  func typedThrowsPreservesFailureType() {
    let action = StructuredAction(
      name: "parity",
      invoke: { (_: Toolbox, value: Int) throws(ParityError) -> Bool in
        guard value >= 0 else {
          throw ParityError()
        }
        return value.isMultiple(of: 2)
      }
    )
    let callee = Toolbox(base: 0)

    do throws(ParityError) {
      let even = try action.invoke(on: callee, with: 4)
      #expect(even == true)
      _ = try action.invoke(on: callee, with: -1)
      Issue.record("Expected ParityError")
    } catch {
      _ = error
    }
  }

  @Test
  func descriptionsBakeIntoSchemas() throws {
    let action = StructuredAction(
      name: "describedDouble",
      description: "Doubles a number",
      inputDescription: "The number to double",
      outputDescription: "The doubled number",
      invoke: { (_: Toolbox, value: Int) in value * 2 }
    )
    #expect(action.description == "Doubles a number")
    try test(
      action.inputSchema,
      encodesAs: #"{"description":"The number to double","type":"integer"}"#
    )
    try test(
      action.outputSchema,
      encodesAs: #"{"description":"The doubled number","type":"integer"}"#
    )
  }

}

/// Defaulted enum-case associated values share an action input's (and
/// struct's) rules: an optional defaulted value may be omitted, a
/// non-optional one is still required.
@Suite
struct EnumerationCaseDefaultTests {

  @Test
  func enumCaseDefaultsFollowStructSemantics() throws {
    try test(#"{"retry": {"count": 5}}"#, decodesAs: Policy.retry(count: 5, delay: nil))
    try test(
      #"{"retry": {"count": 5, "delay": 0.5}}"#,
      decodesAs: Policy.retry(count: 5, delay: 0.5)
    )
    #expect(throws: (any Error).self) {
      try test(#"{"retry": {}}"#, decodesAs: Policy.retry(count: 3, delay: nil))
    }
  }

}

// MARK: - Fixtures

private struct Toolbox {
  var base: Int
}

private struct ParityError: Error {}

@StructuredCodable
private enum Policy: Equatable {
  case retry(count: Int = 3, delay: Double? = nil)
}
