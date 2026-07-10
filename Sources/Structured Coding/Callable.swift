// MARK: - Callable

/// A function exposed through Structured Coding: its parameter clause collapsed
/// onto a `StructuredCodable` `Input`, its return type onto a `StructuredCodable`
/// `Output`, and its effects recorded at the type level — `Failure` is `Never`
/// for non-throwing functions, the thrown type for throwing ones, and
/// `SyncInput` is `Input` for synchronous functions and `Never` for `async`
/// ones (making the synchronous `invoke` overloads uncallable). `Callee` is
/// `Void` for free and static functions and the enclosing type for instance
/// methods.
///
/// Values of this type are constructed by the sidecar function the
/// `@StructuredCallable` macro generates.
public struct StructuredCallable<
  Callee,
  Input: StructuredCodable,
  Output: StructuredCodable,
  SyncInput,
  Failure: Error
> {

  public init(
    name: StaticString,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Callee, Input) throws(Failure) -> Output
  ) where SyncInput == Input {
    self.init(
      name: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: invoke,
      invokeAsync: invoke
    )
  }

  public init(
    name: StaticString,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Input) throws(Failure) -> Output
  ) where SyncInput == Input, Callee == Void {
    self.init(
      name: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, input) throws(Failure) in try invoke(input) },
      invokeAsync: { (_, input) throws(Failure) in try invoke(input) }
    )
  }

  public init(
    name: StaticString,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Callee, Input) async throws(Failure) -> Output
  ) where SyncInput == Never {
    self.init(
      name: name,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription,
      invoke: { (_, _: Never) -> Output in },
      invokeAsync: invoke
    )
  }

  public init(
    name: StaticString,
    description: String? = nil,
    inputDescription: String? = nil,
    outputDescription: String? = nil,
    failure: Failure.Type = Failure.self,
    invoke: @escaping @Sendable (Input) async throws(Failure) -> Output
  ) where SyncInput == Never, Callee == Void {
    self.init(
      name: name,
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

  public let name: String
  public let description: String?

  /// The schemas are stored — with `inputDescription`/`outputDescription`
  /// prepended — rather than derived on access, so a callable's schemas carry
  /// its use-site descriptions the same way `@StructuredProperty` bakes
  /// descriptions into a property's schema.
  public let inputSchema: Input.Schema
  public let outputSchema: Output.Schema

  private init(
    name: StaticString,
    description: String?,
    inputDescription: String?,
    outputDescription: String?,
    invoke: @escaping @Sendable (Callee, SyncInput) throws(Failure) -> Output,
    invokeAsync: @escaping @Sendable (Callee, Input) async throws(Failure) -> Output
  ) {
    self.name = "\(name)"
    self.description = description
    self.inputSchema = Input.schema.prependDescription(inputDescription)
    self.outputSchema = Output.schema.prependDescription(outputDescription)
    self._invoke = invoke
    self._invokeAsync = invokeAsync
  }

  private let _invoke: @Sendable (Callee, SyncInput) throws(Failure) -> Output
  private let _invokeAsync: @Sendable (Callee, Input) async throws(Failure) -> Output

}

extension StructuredCallable: Sendable
where Input.Schema: Sendable, Output.Schema: Sendable {}
