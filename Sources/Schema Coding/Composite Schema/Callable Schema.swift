extension SchemaCoding.Support {

  public struct CallableSchema<
    Callee,
    InputSchema: Schema,
    OutputSchema: Schema,
    SyncInput,
    Failure: Error
  > {

    public init(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke: @escaping (Callee, InputSchema.Value) throws(Failure) -> OutputSchema.Value
    ) where SyncInput == InputSchema.Value {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = invoke
      self._invokeAsync = invoke
    }

    public init(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke: @escaping (InputSchema.Value) throws(Failure) -> OutputSchema.Value
    ) where SyncInput == InputSchema.Value, Callee == Void {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { (_, input) throws(Failure) in try invoke(input) }
      self._invokeAsync = { (_, input) throws(Failure) in try invoke(input) }
    }

    public init(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke:
        @escaping (Callee, InputSchema.Value) async throws(Failure) -> OutputSchema.Value
    ) where SyncInput == Never {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { (_, _: Never) -> OutputSchema.Value in }
      self._invokeAsync = invoke
    }

    public init(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke:
        @escaping (InputSchema.Value) async throws(Failure) -> OutputSchema.Value
    ) where SyncInput == Never, Callee == Void {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { (_, _: Never) -> OutputSchema.Value in }
      self._invokeAsync = { (_, input) throws(Failure) in
        try await invoke(input)
      }
    }

    public func invoke(
      on callee: Callee,
      with input: SyncInput
    ) throws(Failure) -> OutputSchema.Value {
      try _invoke(callee, input)
    }

    public func invoke(
      with input: SyncInput
    ) throws(Failure) -> OutputSchema.Value
    where Callee == Void {
      try _invoke((), input)
    }

    public func invoke(
      on callee: Callee,
      with input: InputSchema.Value
    ) async throws(Failure) -> OutputSchema.Value {
      try await _invokeAsync(callee, input)
    }

    public func invoke(
      with input: InputSchema.Value
    ) async throws(Failure) -> OutputSchema.Value
    where Callee == Void {
      try await _invokeAsync((), input)
    }

    public let name: String
    public let description: String?

    public let inputSchema: InputSchema
    public let outputSchema: OutputSchema

    private let _invoke: (Callee, SyncInput) throws(Failure) -> OutputSchema.Value
    private let _invokeAsync:
      (Callee, InputSchema.Value) async throws(Failure) -> OutputSchema.Value

  }

}
