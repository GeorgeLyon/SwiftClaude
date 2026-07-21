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
/// packs — a composed action is this same type at a fixed placeholder
/// instantiation (see `_StructuredActionGroupInput`) — so the bundle earned
/// nothing and the parameters are flattened.
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
  /// descriptions into a property's schema. A leaf's `inputSchema` is the
  /// action's own raw schema, nothing more — no wrapping, no policy; a
  /// composed action's is the assembled keyed enumeration (see
  /// `_StructuredActionGroupInput`).
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
    self.key = key
    self.description = description
    self.inputSchema = Input.schema.prependDescription(inputDescription)
    self.outputSchema = Output.schema.prependDescription(outputDescription)
    self._invoke = invoke
    self._invokeAsync = invokeAsync
  }

  private let _invoke:
    @Sendable (Callee, SyncInput) throws(Failure) -> Output
  private let _invokeAsync:
    @Sendable (Callee, Input) async throws(Failure) -> Output

}

// MARK: Group Composition

extension StructuredAction
where
  Input == _StructuredActionGroupInput,
  Output == _StructuredActionGroupInput,
  SyncInput == Never,
  Failure == Never
{

  /// Composes several actions into one: the `StructuredAction.Builder` fold
  /// calls this with the assembled keyed enumeration, at the fixed composed
  /// instantiation this extension pins — the uninhabited placeholder
  /// input/output and the effect-free markers. The stored fields reflect
  /// that a composed action is pure schema: a dummy key (a group has no name
  /// of its own — `name` is `""`; a tool's name lives on its definition), no
  /// description, the assembled enumeration in `inputSchema`, an inert
  /// output schema, and invoke closures made statically unreachable by the
  /// uninhabited input.
  init(groupSchema: MetaSchema) {
    self.key = ""
    self.description = nil
    self.inputSchema = _StructuredActionGroupSchema(wrapping: groupSchema)
    self.outputSchema = _StructuredActionGroupSchema(wrapping: .any(description: nil))
    self._invoke = { (_, _: Never) -> _StructuredActionGroupInput in }
    self._invokeAsync = { (_, input) in switch input.never {} }
  }

}
