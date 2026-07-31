// MARK: - Selection

public enum StructuredActionSelection<
  First: StructuredCodable,
  Next: StructuredCodable
> {
  case first(First)
  case next(Next)
}

extension StructuredActionSelection: StructuredObjectRepresentable {}

extension StructuredActionSelection: StructuredCodable {

  public static var schema: StructuredActionCompositionSchema {
    StructuredActionCompositionSchema(
      wrapping: .object(description: nil, maxProperties: 1)
    )
  }

  public func encode(to stream: inout StructuredEncodingStream) throws {
    throw StructuredActionCompositionCodingError.selectionCodingRequiresComposition
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    throw StructuredActionCompositionCodingError.selectionCodingRequiresComposition
  }

}

// MARK: - Result

public enum StructuredActionResult<
  First: StructuredCodable,
  Next: StructuredCodable
> {
  case first(First)
  case next(Next)
}

extension StructuredActionResult: StructuredCodable {

  public static var schema: StructuredActionCompositionSchema {
    StructuredActionCompositionSchema(
      wrapping: .oneOf(description: nil, subschemas: First.schema, Next.schema)
    )
  }

  public func encode(to stream: inout StructuredEncodingStream) throws {
    switch self {
    case .first(let output): try output.encode(to: &stream)
    case .next(let output): try output.encode(to: &stream)
    }
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    throw StructuredActionCompositionCodingError.resultDecodingIsUnsupported
  }

}

// MARK: - Composition Schema

public struct StructuredActionCompositionSchema {

  init(wrapping wrapped: MetaSchema) {
    self.wrapped = wrapped
  }

  var wrapped: MetaSchema

}

extension StructuredActionCompositionSchema: StructuredCodingSchema {

  public var metadata: StructuredCodingSchemaMetadata {
    get { wrapped.metadata }
    set { wrapped.metadata = newValue }
  }

  public static var schema: some StructuredCodingSchema {
    MetaSchema.any(description: nil)
  }

  public func encode(to stream: inout StructuredEncodingStream) throws {
    try wrapped.encode(to: &stream)
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let wrapped = try await MetaSchema.decode(from: &stream, in: context)
    try await accessor.initializeValue(to: Self(wrapping: wrapped))
  }

}

// MARK: - Coding Errors

enum StructuredActionCompositionCodingError: Error {
  case selectionCodingRequiresComposition
  case resultDecodingIsUnsupported
}

// MARK: - Builder

extension StructuredAction {

  /// Deliberately no `buildBlock`, `buildOptional`, `buildEither`, or
  /// `buildArray`: a conditional action would silently change the wire
  /// schema, so control flow in the closure must not compile.
  @resultBuilder
  public enum Builder {

    public static func buildPartialBlock<
      ComponentInput: StructuredCodable,
      ComponentOutput: StructuredCodable,
      ComponentSyncInput,
      ComponentFailure: Error
    >(
      first: StructuredAction<
        Callee, ComponentInput, ComponentOutput, ComponentSyncInput, ComponentFailure
      >
    ) -> StructuredAction<
      Callee, ComponentInput, ComponentOutput, ComponentSyncInput, ComponentFailure
    > {
      first
    }

    // MARK: Folding Two Leaves

    /// Shared output, all-synchronous, non-throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      NextInput: StructuredCodable,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, SharedOutput, FirstInput, Never
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      SharedOutput,
      StructuredActionSelection<FirstInput, NextInput>,
      Never
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: SharedOutput.schema,
        invoke: { (callee, selection) in
          switch selection {
          case .first(let input): accumulatedInvokeSync(callee, input)
          case .next(let input): nextInvokeSync(callee, input)
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): await accumulatedInvoke(callee, input)
          case .next(let input): await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Shared output, all-synchronous, throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstFailure: Error,
      NextInput: StructuredCodable,
      NextFailure: Error,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, SharedOutput, FirstInput, FirstFailure
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      SharedOutput,
      StructuredActionSelection<FirstInput, NextInput>,
      any Error
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: SharedOutput.schema,
        invoke: { (callee, selection) in
          switch selection {
          case .first(let input): try accumulatedInvokeSync(callee, input)
          case .next(let input): try nextInvokeSync(callee, input)
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): try await accumulatedInvoke(callee, input)
          case .next(let input): try await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Shared output, at least one asynchronous component, non-throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstSyncInput,
      NextInput: StructuredCodable,
      NextSyncInput,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, SharedOutput, FirstSyncInput, Never
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextSyncInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      SharedOutput,
      Never,
      Never
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: SharedOutput.schema,
        invoke: { (_, _: Never) -> SharedOutput in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): await accumulatedInvoke(callee, input)
          case .next(let input): await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Shared output, at least one asynchronous component, throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstSyncInput,
      FirstFailure: Error,
      NextInput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, SharedOutput, FirstSyncInput, FirstFailure
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextSyncInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      SharedOutput,
      Never,
      any Error
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: SharedOutput.schema,
        invoke: { (_, _: Never) -> SharedOutput in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): try await accumulatedInvoke(callee, input)
          case .next(let input): try await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Differing outputs, all-synchronous, non-throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstOutput: StructuredCodable,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, FirstOutput, FirstInput, Never
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      StructuredActionResult<FirstOutput, NextOutput>,
      StructuredActionSelection<FirstInput, NextInput>,
      Never
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (callee, selection) in
          switch selection {
          case .first(let input): .first(accumulatedInvokeSync(callee, input))
          case .next(let input): .next(nextInvokeSync(callee, input))
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): .first(await accumulatedInvoke(callee, input))
          case .next(let input): .next(await nextInvoke(callee, input))
          }
        }
      )
    }

    /// Differing outputs, all-synchronous, throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstOutput: StructuredCodable,
      FirstFailure: Error,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextFailure: Error
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, FirstOutput, FirstInput, FirstFailure
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      StructuredActionResult<FirstOutput, NextOutput>,
      StructuredActionSelection<FirstInput, NextInput>,
      any Error
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (callee, selection) in
          switch selection {
          case .first(let input): .first(try accumulatedInvokeSync(callee, input))
          case .next(let input): .next(try nextInvokeSync(callee, input))
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): .first(try await accumulatedInvoke(callee, input))
          case .next(let input): .next(try await nextInvoke(callee, input))
          }
        }
      )
    }

    /// Differing outputs, at least one asynchronous component, non-throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstOutput: StructuredCodable,
      FirstSyncInput,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, FirstOutput, FirstSyncInput, Never
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      StructuredActionResult<FirstOutput, NextOutput>,
      Never,
      Never
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (_, _: Never) -> StructuredActionResult<FirstOutput, NextOutput> in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): .first(await accumulatedInvoke(callee, input))
          case .next(let input): .next(await nextInvoke(callee, input))
          }
        }
      )
    }

    /// Differing outputs, at least one asynchronous component, throwing.
    public static func buildPartialBlock<
      FirstInput: StructuredCodable,
      FirstOutput: StructuredCodable,
      FirstSyncInput,
      FirstFailure: Error,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error
    >(
      accumulated: StructuredAction<
        Callee, FirstInput, FirstOutput, FirstSyncInput, FirstFailure
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<FirstInput, NextInput>,
      StructuredActionResult<FirstOutput, NextOutput>,
      Never,
      any Error
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: enumeratedInputSchema(folding: accumulated, with: next),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (_, _: Never) -> StructuredActionResult<FirstOutput, NextOutput> in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let input): .first(try await accumulatedInvoke(callee, input))
          case .next(let input): .next(try await nextInvoke(callee, input))
          }
        }
      )
    }

    // MARK: Appending to a Composition

    /// Shared output, all-synchronous, non-throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      NextInput: StructuredCodable,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, SharedOutput, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, Never
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      SharedOutput,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      Never
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: SharedOutput.schema,
        invoke: { (callee, selection) in
          switch selection {
          case .first(let inner): accumulatedInvokeSync(callee, inner)
          case .next(let input): nextInvokeSync(callee, input)
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): await accumulatedInvoke(callee, inner)
          case .next(let input): await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Shared output, all-synchronous, throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedFailure: Error,
      NextInput: StructuredCodable,
      NextFailure: Error,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, SharedOutput, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, AccumulatedFailure
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      SharedOutput,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      any Error
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: SharedOutput.schema,
        invoke: { (callee, selection) in
          switch selection {
          case .first(let inner): try accumulatedInvokeSync(callee, inner)
          case .next(let input): try nextInvokeSync(callee, input)
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): try await accumulatedInvoke(callee, inner)
          case .next(let input): try await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Shared output, at least one asynchronous component, non-throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedSyncInput,
      NextInput: StructuredCodable,
      NextSyncInput,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, SharedOutput, AccumulatedSyncInput, Never
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextSyncInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      SharedOutput,
      Never,
      Never
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: SharedOutput.schema,
        invoke: { (_, _: Never) -> SharedOutput in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): await accumulatedInvoke(callee, inner)
          case .next(let input): await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Shared output, at least one asynchronous component, throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedSyncInput,
      AccumulatedFailure: Error,
      NextInput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error,
      SharedOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, SharedOutput, AccumulatedSyncInput, AccumulatedFailure
      >,
      next: StructuredAction<Callee, NextInput, SharedOutput, NextSyncInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      SharedOutput,
      Never,
      any Error
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: SharedOutput.schema,
        invoke: { (_, _: Never) -> SharedOutput in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): try await accumulatedInvoke(callee, inner)
          case .next(let input): try await nextInvoke(callee, input)
          }
        }
      )
    }

    /// Differing outputs, all-synchronous, non-throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedOutput: StructuredCodable,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, AccumulatedOutput, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, Never
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      StructuredActionResult<AccumulatedOutput, NextOutput>,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      Never
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (callee, selection) in
          switch selection {
          case .first(let inner): .first(accumulatedInvokeSync(callee, inner))
          case .next(let input): .next(nextInvokeSync(callee, input))
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): .first(await accumulatedInvoke(callee, inner))
          case .next(let input): .next(await nextInvoke(callee, input))
          }
        }
      )
    }

    /// Differing outputs, all-synchronous, throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedOutput: StructuredCodable,
      AccumulatedFailure: Error,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextFailure: Error
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, AccumulatedOutput, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, AccumulatedFailure
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      StructuredActionResult<AccumulatedOutput, NextOutput>,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      any Error
    > {
      let accumulatedInvokeSync = accumulated._invoke
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvokeSync = next._invoke
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (callee, selection) in
          switch selection {
          case .first(let inner): .first(try accumulatedInvokeSync(callee, inner))
          case .next(let input): .next(try nextInvokeSync(callee, input))
          }
        },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): .first(try await accumulatedInvoke(callee, inner))
          case .next(let input): .next(try await nextInvoke(callee, input))
          }
        }
      )
    }

    /// Differing outputs, at least one asynchronous component, non-throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedOutput: StructuredCodable,
      AccumulatedSyncInput,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, AccumulatedOutput, AccumulatedSyncInput, Never
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, Never>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      StructuredActionResult<AccumulatedOutput, NextOutput>,
      Never,
      Never
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (_, _: Never) -> StructuredActionResult<AccumulatedOutput, NextOutput> in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): .first(await accumulatedInvoke(callee, inner))
          case .next(let input): .next(await nextInvoke(callee, input))
          }
        }
      )
    }

    /// Differing outputs, at least one asynchronous component, throwing.
    public static func buildPartialBlock<
      AccumulatedFirst: StructuredCodable,
      AccumulatedNext: StructuredCodable,
      AccumulatedOutput: StructuredCodable,
      AccumulatedSyncInput,
      AccumulatedFailure: Error,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error
    >(
      accumulated: StructuredAction<
        Callee, StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, AccumulatedOutput, AccumulatedSyncInput, AccumulatedFailure
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, NextFailure>
    ) -> StructuredAction<
      Callee,
      StructuredActionSelection<StructuredActionSelection<AccumulatedFirst, AccumulatedNext>, NextInput>,
      StructuredActionResult<AccumulatedOutput, NextOutput>,
      Never,
      any Error
    > {
      let accumulatedInvoke = accumulated._invokeAsync
      let nextInvoke = next._invokeAsync
      return .init(
        key: "",
        description: nil,
        inputSchema: splicedInputSchema(splicing: next, into: accumulated.inputSchema),
        outputSchema: resultOutputSchema(
          first: accumulated.outputSchema,
          next: next.outputSchema
        ),
        invoke: { (_, _: Never) -> StructuredActionResult<AccumulatedOutput, NextOutput> in },
        invokeAsync: { (callee, selection) in
          switch selection {
          case .first(let inner): .first(try await accumulatedInvoke(callee, inner))
          case .next(let input): .next(try await nextInvoke(callee, input))
          }
        }
      )
    }

    // MARK: Schema Assembly

    private static func enumeratedInputSchema<
      FirstInput: StructuredCodable,
      FirstOutput: StructuredCodable,
      FirstSyncInput,
      FirstFailure: Error,
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error
    >(
      folding accumulated: StructuredAction<
        Callee, FirstInput, FirstOutput, FirstSyncInput, FirstFailure
      >,
      with next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, NextFailure>
    ) -> StructuredActionCompositionSchema {
      precondition(
        accumulated.name != next.name,
        "Duplicate action name \"\(next.name)\"; a tool's actions must have unique names"
      )
      return StructuredActionCompositionSchema(
        wrapping: .object(
          description: nil,
          maxProperties: 1,
          properties:
            (
              accumulated.key,
              accumulated.inputSchema.prependDescription(accumulated.description),
              false
            ),
            (
              next.key,
              next.inputSchema.prependDescription(next.description),
              false
            )
        )
      )
    }

    private static func splicedInputSchema<
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error
    >(
      splicing next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, NextFailure>,
      into accumulated: StructuredActionCompositionSchema
    ) -> StructuredActionCompositionSchema {
      var wrapped = accumulated.wrapped
      for existingName in wrapped.propertyNames {
        precondition(
          existingName != next.name,
          "Duplicate action name \"\(next.name)\"; a tool's actions must have unique names"
        )
      }
      wrapped.appendProperty(
        named: next.key,
        schema: next.inputSchema.prependDescription(next.description)
      )
      return StructuredActionCompositionSchema(wrapping: wrapped)
    }

    private static func resultOutputSchema(
      first: some StructuredEncodable,
      next: some StructuredEncodable
    ) -> StructuredActionCompositionSchema {
      StructuredActionCompositionSchema(
        wrapping: .oneOf(description: nil, subschemas: first, next)
      )
    }

  }

}

// MARK: - Build

extension StructuredAction
where
  Callee == Never,
  Input == StructuredEmptyObject,
  Output == StructuredEmptyObject,
  SyncInput == Never,
  Failure == Never
{

  public static func build<
    C,
    I: StructuredCodable,
    O: StructuredCodable,
    SI,
    F: Error
  >(
    @StructuredAction<C, StructuredEmptyObject, StructuredEmptyObject, Never, Never>.Builder
    _ actions: () -> StructuredAction<C, I, O, SI, F>
  ) -> StructuredAction<C, I, O, SI, F> {
    actions()
  }

}
