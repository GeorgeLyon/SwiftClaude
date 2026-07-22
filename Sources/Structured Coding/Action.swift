// MARK: - Action

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

  let key: StructuredCodingKey

  public let description: String?

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

  let _invoke:
    @Sendable (Callee, SyncInput) throws(Failure) -> Output
  let _invokeAsync:
    @Sendable (Callee, Input) async throws(Failure) -> Output

}
