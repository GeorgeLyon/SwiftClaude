extension SchemaCoding.Support {

  public struct FunctionDefinition<
    Callee,
    InputSchema: Schema,
    OutputSchema: Schema,
    AsyncInputSchema: Schema,
    AsyncOutputSchema: Schema,
    Failure: Error
  > {

    public init(
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke: @escaping (Callee, InputSchema.Value) throws(Failure) -> OutputSchema.Value
    ) where AsyncInputSchema == InputSchema, AsyncOutputSchema == OutputSchema {
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = invoke
      self._invokeAsync = invoke
    }

    public init(
      inputSchema: AsyncInputSchema,
      outputSchema: AsyncOutputSchema,
      failure: Failure.Type = Failure.self,
      invoke:
        @escaping (Callee, AsyncInputSchema.Value) async throws(Failure) -> AsyncOutputSchema.Value
    ) where InputSchema == NeverSchema, OutputSchema == NeverSchema {
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { (_, _: Never) -> OutputSchema.Value in }
      self._invokeAsync = invoke
    }

    public func invoke(
      on callee: Callee,
      with input: InputSchema.Value
    ) throws(Failure) -> OutputSchema.Value {
      try _invoke(callee, input)
    }

    public func invoke(
      on callee: Callee,
      with input: AsyncInputSchema.Value
    ) async throws(Failure) -> AsyncOutputSchema.Value {
      try await _invokeAsync(callee, input)
    }

    public let inputSchema: AsyncInputSchema
    public let outputSchema: AsyncOutputSchema

    private let _invoke: (Callee, InputSchema.Value) throws(Failure) -> OutputSchema.Value
    private let _invokeAsync:
      (Callee, AsyncInputSchema.Value) async throws(Failure) -> AsyncOutputSchema.Value

  }

}
