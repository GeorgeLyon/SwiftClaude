// MARK: - Action Signature

/// The value-independent shape of a `StructuredAction`: the `StructuredCodable`
/// `Input` its parameter clause collapses onto, the `StructuredCodable`
/// `Output` its return type collapses onto, and its effects recorded at the
/// type level — `Failure` is `Never` for non-throwing functions, the thrown
/// type for throwing ones, and `SyncInput` is `Input` for synchronous
/// functions and `Never` for `async` ones (making the synchronous `invoke`
/// overloads uncallable).
///
/// Bundling these into one marker keeps `StructuredAction` generic over
/// exactly two parameters, which is what lets `StructuredToolDefinition` be
/// generic over a single pack of signatures with a scalar `Callee`: a generic
/// type may declare at most one type pack, and pinning every pack element's
/// `Callee` associated type to a scalar parameter would be a same-element
/// requirement, which the compiler does not yet support.
public protocol StructuredActionSignatureProtocol {
  associatedtype Input: StructuredCodable
  associatedtype Output: StructuredCodable
  associatedtype SyncInput
  associatedtype Failure: Error
}

/// The uninhabited marker type carrying a `StructuredAction`'s signature; see
/// `StructuredActionSignatureProtocol`. Never spelled directly: the same-type
/// constraints on `StructuredAction`'s initializers infer it — for the inline
/// actions `@StructuredTool` generates and hand-written ones alike.
public enum StructuredActionSignature<
  Input: StructuredCodable,
  Output: StructuredCodable,
  SyncInput,
  Failure: Error
>: StructuredActionSignatureProtocol {}

// MARK: - Action

/// A function exposed through Structured Coding, its shape recorded by a
/// `StructuredActionSignatureProtocol` marker. `Callee` is `Void` for static
/// functions and the enclosing type for instance methods.
///
/// Values of this type are constructed inline by the `@StructuredTool`
/// macro's generated `definition`, or by hand.
public struct StructuredAction<Callee, Signature: StructuredActionSignatureProtocol> {

  public init<Input, Output, Failure>(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Callee, Input) throws(Failure) -> Output
  ) where Signature == StructuredActionSignature<Input, Output, Input, Failure> {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: invoke,
      invokeAsync: invoke
    )
  }

  public init<Input, Output, Failure>(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Input) throws(Failure) -> Output
  ) where Signature == StructuredActionSignature<Input, Output, Input, Failure>, Callee == Void {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, input) throws(Failure) in try invoke(input) },
      invokeAsync: { (_, input) throws(Failure) in try invoke(input) }
    )
  }

  public init<Input, Output, Failure>(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Callee, Input) async throws(Failure) -> Output
  ) where Signature == StructuredActionSignature<Input, Output, Never, Failure> {
    self.init(
      key: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, _: Never) -> Output in },
      invokeAsync: invoke
    )
  }

  public init<Input, Output, Failure>(
    name: StructuredCodingKey,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Input) async throws(Failure) -> Output
  ) where Signature == StructuredActionSignature<Input, Output, Never, Failure>, Callee == Void {
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
    with input: Signature.SyncInput
  ) throws(Signature.Failure) -> Signature.Output {
    try _invoke(callee, input)
  }

  public func invoke(
    with input: Signature.SyncInput
  ) throws(Signature.Failure) -> Signature.Output
  where Callee == Void {
    try _invoke((), input)
  }

  public func invoke(
    on callee: Callee,
    with input: Signature.Input
  ) async throws(Signature.Failure) -> Signature.Output {
    try await _invokeAsync(callee, input)
  }

  public func invoke(
    with input: Signature.Input
  ) async throws(Signature.Failure) -> Signature.Output
  where Callee == Void {
    try await _invokeAsync((), input)
  }

  public var name: String {
    key.stringValue
  }

  /// The `StaticString`-backed form of `name`, kept so a tool definition can
  /// pass it straight into its enumeration schema's property list.
  let key: StructuredCodingKey

  public let description: String?

  /// The schemas are stored — with `inputDescription`/`outputDescription`
  /// prepended — rather than derived on access, so an action's schemas carry
  /// its use-site descriptions the same way `@StructuredProperty` bakes
  /// descriptions into a property's schema.
  public let inputSchema: Signature.Input.Schema
  public let outputSchema: Signature.Output.Schema

  private init(
    key: StructuredCodingKey,
    description: String?,
    inputDescription: String?,
    outputDescription: String?,
    invoke: @escaping @Sendable (Callee, Signature.SyncInput) throws(Signature.Failure) ->
      Signature.Output,
    invokeAsync: @escaping @Sendable (Callee, Signature.Input) async throws(Signature.Failure) ->
      Signature.Output
  ) {
    self.key = key
    self.description = description
    self.inputSchema = Signature.Input.schema.prependDescription(inputDescription)
    self.outputSchema = Signature.Output.schema.prependDescription(outputDescription)
    self._invoke = invoke
    self._invokeAsync = invokeAsync
  }

  private let _invoke:
    @Sendable (Callee, Signature.SyncInput) throws(Signature.Failure) -> Signature.Output
  private let _invokeAsync:
    @Sendable (Callee, Signature.Input) async throws(Signature.Failure) -> Signature.Output

}

extension StructuredAction: Sendable
where Signature.Input.Schema: Sendable, Signature.Output.Schema: Sendable {}
