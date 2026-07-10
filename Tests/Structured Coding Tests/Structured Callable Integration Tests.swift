import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// End-to-end coverage for `@StructuredCallable`: JSON is decoded into the
/// collapsed Input, the decorated function is invoked through the generated
/// glue, and the result is encoded from the collapsed Output — for every
/// collapse shape and effect combination.
@Suite
struct StructuredCallableIntegrationTests {

  @Test
  func instanceMethodObjectInputRoundTrips() async throws {
    let result = try await invokeJSON(
      Calculator.__structuredCallable_add(),
      on: Calculator(base: 2),
      input: #"{"amount": 3}"#
    )
    #expect(result == "5")
  }

  @Test
  func mixedTupleInputObjectOutputRoundTrips() async throws {
    let result = try await invokeJSON(
      Calculator.__structuredCallable_flip(),
      on: Calculator(base: 0),
      input: "[true, false]"
    )
    #expect(result == #"{"a":false,"b":true}"#)
  }

  @Test
  func voidOutputAndEmptyInputCodeAsEmptyObjects() async throws {
    let result = try await invokeJSON(
      Calculator.__structuredCallable_ping(),
      on: Calculator(base: 0),
      input: "{}"
    )
    #expect(result == "{}")
  }

  /// Defaults follow struct (`var x: T = expr`) semantics exactly: a
  /// non-optional defaulted parameter is still required in the JSON — the
  /// default seeds partial streaming, it does not make the key omittable
  /// (see `DefaultInitializedPropertyTests`).
  @Test
  func nonOptionalDefaultedParameterIsStillRequired() async throws {
    let supplied = try await invokeJSON(
      Calculator.__structuredCallable_greet(),
      on: Calculator(base: 0),
      input: #"{"name": "moon"}"#
    )
    #expect(supplied == #""Hello, moon""#)

    await #expect(throws: (any Error).self) {
      _ = try await invokeJSON(
        Calculator.__structuredCallable_greet(),
        on: Calculator(base: 0),
        input: "{}"
      )
    }
  }

  @Test
  func optionalDefaultedParameterMayBeOmitted() async throws {
    let result = try await invokeJSON(
      Calculator.__structuredCallable_log(),
      on: Calculator(base: 0),
      input: #"{"message": "hi"}"#
    )
    #expect(result == #""hi@none""#)
  }

  /// A synchronous function's callable can be invoked without suspending
  /// (`SyncInput == Input`), and a static method needs no callee.
  @Test
  func staticMethodInvokesSynchronouslyWithoutCallee() throws {
    let callable = Calculator.__structuredCallable_double()
    let input: Int = try decodeValue("21")
    #expect(callable.invoke(with: input) == 42)
  }

  @Test
  func topLevelFunctionInvokes() {
    let callable = __structuredCallable_negate()
    #expect(callable.invoke(with: true) == false)
  }

  @Test
  func asyncFunctionInvokes() async throws {
    let result = try await invokeJSON(
      Calculator.__structuredCallable_fetch(),
      on: Calculator(base: 0),
      input: #"{"id": 7}"#
    )
    #expect(result == #""item-7""#)
  }

  /// `throws(E)` survives into the callable: the `do throws(ParityError)`
  /// block only compiles because `Failure == ParityError`.
  @Test
  func typedThrowsPreservesFailureType() throws {
    let callable = Calculator.__structuredCallable_parity()
    let callee = Calculator(base: 0)

    let even = try callable.invoke(on: callee, with: decodeInput(callable, #"{"of": 4}"#))
    #expect(even == true)

    let negative = try decodeInput(callable, #"{"of": -1}"#)
    do throws(ParityError) {
      _ = try callable.invoke(on: callee, with: negative)
      Issue.record("Expected ParityError")
    } catch {
      _ = error
    }
  }

  @Test
  func untypedThrowsPropagates() async throws {
    let callable = Calculator.__structuredCallable_head()
    await #expect(throws: NoElementsError.self) {
      _ = try await invokeJSON(callable, on: Calculator(base: 0), input: "[]")
    }
  }

  /// Two `over(x:)` overloads produce two sidecars, disambiguated by their
  /// defaulted metatype parameters.
  @Test
  func overloadsDisambiguateByMetatypeParameters() throws {
    let intCallable = Calculator.__structuredCallable_over(x: Int.self)
    let stringCallable = Calculator.__structuredCallable_over(x: String.self)
    let callee = Calculator(base: 0)

    #expect(try intCallable.invoke(on: callee, with: decodeInput(intCallable, #"{"x": 1}"#)) == 1)
    #expect(
      try stringCallable.invoke(on: callee, with: decodeInput(stringCallable, #"{"x": "a"}"#))
        == "a")
  }

  @Test
  func nameAndDescriptionsAreExposed() throws {
    let callable = Calculator.__structuredCallable_describedAdd()
    #expect(callable.name == "describedAdd(a:b:)")
    #expect(callable.description == "Adds two numbers")
    try test(
      callable.inputSchema,
      encodesAs:
        #"{"description":"The addends","properties":{"a":{"type":"integer"},"b":{"type":"integer"}},"required":["a","b"]}"#
    )
    try test(
      callable.outputSchema,
      encodesAs: #"{"description":"The sum","type":"integer"}"#
    )
  }

  /// Defaulted enum-case associated values share the callable's (and struct's)
  /// rules: an optional defaulted value may be omitted, a non-optional one is
  /// still required.
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

private struct Calculator {
  var base: Int

  @StructuredCallable
  func add(amount: Int) -> Int {
    base + amount
  }

  @StructuredCallable
  func flip(bar: Bool, _ baz: Bool) throws -> (a: Bool, b: Bool) {
    (baz, bar)
  }

  @StructuredCallable
  func ping() {
  }

  @StructuredCallable
  func greet(name: String = "world") -> String {
    "Hello, \(name)"
  }

  @StructuredCallable
  func log(message: String, level: Int? = nil) -> String {
    "\(message)@\(level.map(String.init) ?? "none")"
  }

  @StructuredCallable
  static func double(_ value: Int) -> Int {
    value * 2
  }

  @StructuredCallable
  func fetch(id: Int) async -> String {
    "item-\(id)"
  }

  @StructuredCallable
  func parity(of value: Int) throws(ParityError) -> Bool {
    guard value >= 0 else {
      throw ParityError()
    }
    return value.isMultiple(of: 2)
  }

  @StructuredCallable
  func head(_ values: [Int]) throws -> Int {
    guard let first = values.first else {
      throw NoElementsError()
    }
    return first
  }

  @StructuredCallable(
    description: "Adds two numbers",
    inputDescription: "The addends",
    outputDescription: "The sum"
  )
  func describedAdd(a: Int, b: Int) -> Int {
    a + b
  }

  @StructuredCallable
  func over(x: Int) -> Int {
    x
  }

  @StructuredCallable
  func over(x: String) -> String {
    x
  }
}

@StructuredCallable
private func negate(_ value: Bool) -> Bool {
  !value
}

private struct ParityError: Error {}
private struct NoElementsError: Error {}

@StructuredCodable
private enum Policy: Equatable {
  case retry(count: Int = 3, delay: Double? = nil)
}

// MARK: - Helpers

/// Decodes a complete JSON document as `Value`.
private func decodeValue<Value: StructuredDecodable>(_ json: String) throws -> Value {
  let decoder = IncrementalDecoder()
  let session: DecodingSession<Value> = decoder.startDecoding { stream in
    let value = try await stream.withDecoder { decoder in
      try await Value.decode(from: &decoder, in: StructuredDecodingContext())
    }
    try await stream.readTrailingWhitespace()
    return value
  }
  session.stream(json.utf8)
  session.streamingComplete()
  return try session.value
}

/// Decodes `json` as the Input of `callable`, letting the callable pin the
/// decoded type so call sites never spell the synthesized Input's name.
private func decodeInput<Callee, Input, Output, SyncInput, Failure>(
  _ callable: StructuredCallable<Callee, Input, Output, SyncInput, Failure>,
  _ json: String
) throws -> Input {
  try decodeValue(json)
}

/// Decodes `json` as the Input, invokes, and encodes the Output — the full
/// path a tool invocation would take.
private func invokeJSON<Callee, Input, Output, SyncInput, Failure>(
  _ callable: StructuredCallable<Callee, Input, Output, SyncInput, Failure>,
  on callee: Callee,
  input json: String
) async throws -> String {
  let input: Input = try decodeValue(json)
  let output = try await callable.invoke(on: callee, with: input)
  var encoder = StructuredEncoder()
  try output.encode(to: &encoder)
  return encoder.stringValue
}
