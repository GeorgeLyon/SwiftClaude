extension SchemaCoding.Support {

  public struct CallableSchema<
    Callee,
    InputSchema: Schema,
    OutputSchema: Schema,
    SyncInput,
    Failure: Error
  > {

    public init<each Parameter>(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke: @escaping (Callee) -> (repeat each Parameter) throws(Failure) -> OutputSchema.Value
    ) where SyncInput == InputSchema.Value, InputSchema.Value == (repeat each Parameter) {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { callee in
        { parameters throws(Failure) in
          try invoke(callee)(repeat each parameters)
        }
      }
      self._invokeAsync = _invoke
    }

    public init<each Parameter>(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke: @escaping (repeat each Parameter) throws(Failure) -> OutputSchema.Value
    )
    where
      SyncInput == InputSchema.Value,
      InputSchema.Value == (repeat each Parameter),
      Callee == Void
    {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { _ in
        { parameters throws(Failure) in
          try invoke(repeat each parameters)
        }
      }
      self._invokeAsync = _invoke
    }

    public init<each Parameter>(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke:
        @escaping (Callee) -> (repeat each Parameter) async throws(Failure) -> OutputSchema.Value
    ) where SyncInput == Never, InputSchema.Value == (repeat each Parameter) {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { _ in { (_: Never) -> OutputSchema.Value in } }
      self._invokeAsync = { callee in
        { parameters throws(Failure) in
          try await invoke(callee)(repeat each parameters)
        }
      }
    }

    public init<each Parameter>(
      name: StaticString,
      description: String? = nil,
      inputSchema: InputSchema,
      outputSchema: OutputSchema,
      failure: Failure.Type = Failure.self,
      invoke:
        @escaping (repeat each Parameter) async throws(Failure) -> OutputSchema.Value
    ) where SyncInput == Never, InputSchema.Value == (repeat each Parameter), Callee == Void {
      self.name = "\(name)"
      self.description = description
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
      self._invoke = { _ in { (_: Never) -> OutputSchema.Value in } }
      self._invokeAsync = { _ in
        { parameters throws(Failure) in
          try await invoke(repeat each parameters)
        }
      }
    }

    public func invoke(
      on callee: Callee,
      with input: SyncInput
    ) throws(Failure) -> OutputSchema.Value {
      try _invoke(callee)(input)
    }

    public func invoke(
      with input: SyncInput
    ) throws(Failure) -> OutputSchema.Value
    where Callee == Void {
      try _invoke(())(input)
    }

    public func invoke(
      on callee: Callee,
      with input: InputSchema.Value
    ) async throws(Failure) -> OutputSchema.Value {
      try await _invokeAsync(callee)(input)
    }

    public func invoke(
      with input: InputSchema.Value
    ) async throws(Failure) -> OutputSchema.Value
    where Callee == Void {
      try await _invokeAsync(())(input)
    }

    public let name: String
    public let description: String?

    public let inputSchema: InputSchema
    public let outputSchema: OutputSchema

    private let _invoke: (Callee) -> (SyncInput) throws(Failure) -> OutputSchema.Value
    private let _invokeAsync:
      (Callee) -> (InputSchema.Value) async throws(Failure) -> OutputSchema.Value

  }

}
