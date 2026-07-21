// MARK: - Action

/// A function exposed through Structured Coding: the `StructuredCodable`
/// `Input` its parameter clause collapses onto, the `StructuredCodable`
/// `Output` its return type collapses onto, and its effects recorded at the
/// type level — `Failure` is `Never` for non-throwing functions, the thrown
/// type for throwing ones, and `SyncInput` is `Input` for synchronous
/// functions and `Never` for `async` ones (making the synchronous `invoke`
/// overloads uncallable). `Callee` is `Void` for static functions and the
/// enclosing type for instance methods.
///
/// The shape parameters used to be bundled behind a signature marker type:
/// a generic type may declare at most one type pack, and while a composed
/// multi-action group packed over per-action shapes, keeping the action
/// generic over exactly two parameters (callee + bundle) was what made that
/// pack expressible under a scalar `Callee` without same-element
/// requirements (which the compiler does not support). Composition no longer
/// packs — several actions fold into a composed `StructuredAction` whose
/// input nests `StructuredActionSelection` pairwise, mirroring the fold —
/// so the bundle earned nothing and the parameters are flattened.
///
/// Values of this type are constructed inline by the `@StructuredTool`
/// macro's generated `Definition`, or by hand; the generic arguments are
/// always inferred from the initializer, never spelled.
public struct StructuredAction<
  Callee,
  Input: StructuredCodable,
  Output: StructuredCodable,
  SyncInput,
  Failure: Error
> {

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Callee, Input) throws(Failure) -> Output
  ) where SyncInput == Input {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: invoke,
      invokeAsync: invoke
    )
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Input) throws(Failure) -> Output
  ) where SyncInput == Input, Callee == Void {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, input) throws(Failure) in try invoke(input) },
      invokeAsync: { (_, input) throws(Failure) in try invoke(input) }
    )
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Callee, Input) async throws(Failure) -> Output
  ) where SyncInput == Never {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, _: Never) -> Output in },
      invokeAsync: invoke
    )
  }

  public init(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Input) async throws(Failure) -> Output
  ) where SyncInput == Never, Callee == Void {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, _: Never) -> Output in },
      invokeAsync: { (_, input) async throws(Failure) in try await invoke(input) }
    )
  }

  public func invoke(
    on callee: Callee,
    with input: SyncInput
  ) throws(Failure) -> Output {
    try _invoke(callee, input)
  }

  public func invoke(
    with input: SyncInput
  ) throws(Failure) -> Output
  where Callee == Void {
    try _invoke((), input)
  }

  public func invoke(
    on callee: Callee,
    with input: Input
  ) async throws(Failure) -> Output {
    try await _invokeAsync(callee, input)
  }

  public func invoke(
    with input: Input
  ) async throws(Failure) -> Output
  where Callee == Void {
    try await _invokeAsync((), input)
  }

  public var name: String {
    key.stringValue
  }

  /// The `StaticString`-backed form of `name`, kept so the composition fold
  /// can pass it straight into an enumeration schema's property list.
  let key: StructuredCodingKey

  public let description: String?

  /// The schemas are stored — with `inputDescription`/`outputDescription`
  /// prepended — rather than derived on access, so an action's schemas carry
  /// its use-site descriptions the same way `@StructuredProperty` bakes
  /// descriptions into a property's schema. A leaf's `inputSchema` is its
  /// own raw schema, nothing more — no wrapping, no policy; a composed
  /// action stores the assembled keyed input enumeration and the collapsed
  /// or `oneOf` output schema (see `StructuredActionSelection` and
  /// `StructuredActionResult`).
  public let inputSchema: Input.Schema
  public let outputSchema: Output.Schema

  private init(
    key: StructuredCodingKey,
    description: String?,
    inputDescription: String?,
    outputDescription: String?,
    invoke: @escaping @Sendable (Callee, SyncInput) throws(Failure) -> Output,
    invokeAsync: @escaping @Sendable (Callee, Input) async throws(Failure) -> Output
  ) {
    self.init(
      key: key,
      description: description,
      inputSchema: Input.schema.prependDescription(inputDescription),
      outputSchema: Output.schema.prependDescription(outputDescription),
      invoke: invoke,
      invokeAsync: invokeAsync
    )
  }

  /// The composition fold's entry point: the public initializers above
  /// derive the stored schemas from `Input.schema`/`Output.schema`, while
  /// `StructuredAction.Builder` assembles a composed action's schemas at
  /// fold time and stores them directly.
  init(
    key: StructuredCodingKey,
    description: String?,
    inputSchema: Input.Schema,
    outputSchema: Output.Schema,
    invoke: @escaping @Sendable (Callee, SyncInput) throws(Failure) -> Output,
    invokeAsync: @escaping @Sendable (Callee, Input) async throws(Failure) -> Output
  ) {
    self.key = key
    self.description = description
    self.inputSchema = inputSchema
    self.outputSchema = outputSchema
    self._invoke = invoke
    self._invokeAsync = invokeAsync
  }

  /// Internal rather than private: `StructuredAction.Builder`'s fold
  /// captures the component actions' stored invokes directly — the closures
  /// are `@Sendable` where the actions themselves (whose stored schemas
  /// hold deferred encoding state) are not.
  let _invoke:
    @Sendable (Callee, SyncInput) throws(Failure) -> Output
  let _invokeAsync:
    @Sendable (Callee, Input) async throws(Failure) -> Output

}
