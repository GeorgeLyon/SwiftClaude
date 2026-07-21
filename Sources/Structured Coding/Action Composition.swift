// MARK: - Selection

/// The enum argument of a composed action: exactly one component's input,
/// tagged by position. Composing two or more actions yields a value
/// *structurally equivalent to a single action with an enum argument* — the
/// `StructuredAction.Builder` folds leaf `StructuredAction`s into a plain
/// `StructuredAction` whose `Input` is a selection, nesting pairwise the way
/// the builder folds: three actions with inputs `I1`, `I2`, `I3` compose to
/// `StructuredActionSelection<StructuredActionSelection<I1, I2>, I3>`, and
/// a value selecting the second action is `.first(.next(i2))`. Nothing is
/// erased: the payload types are the components' own input types, invoking
/// a composed action dispatches by `switch` — no names, no casts — and the
/// composed type records the whole composition. There is no separate group
/// type, and consumers classify a composed tool with the same constraints
/// that classify a leaf: a selection is `StructuredObjectRepresentable`
/// (its wire form is the keyed enumeration, a top-level object by
/// construction), so a top-level-object requirement admits a composition
/// through the very overload that admits a lone object-input action.
///
/// On the wire a selection is keyed by action *name* — the composed
/// action's stored `inputSchema` is the assembled keyed enumeration, an
/// object keyed by action name (`maxProperties: 1` constrains the
/// selection), each key carrying its action's input schema with the action
/// description prepended. Names are fold-time *values*, invisible to the
/// type system, so the static coding witnesses here are degenerate: the
/// static `schema` is the empty enumeration (the real one is assembled by
/// the fold and stored on the action), and `encode`/`decode` throw —
/// mapping case paths to names is the composition's business, and arrives
/// with dispatch (a later round). Selections are constructed directly —
/// `.first(.next(input))` — and consumed by the composed action's typed
/// invoke.
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

  public func encode(to encoder: inout StructuredEncoder) throws {
    throw StructuredActionCompositionCodingError.selectionCodingRequiresComposition
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    throw StructuredActionCompositionCodingError.selectionCodingRequiresComposition
  }

}

// MARK: - Result

/// The enum result of a composed action, mirroring `StructuredActionSelection`
/// on the output side — but only where it must: the builder folds two
/// actions with the *same* output type into a composed action returning
/// that type directly, and reaches for this nested sum only when the output
/// types differ. (A composition of `Int`-returning actions returns `Int`;
/// mix in a `String`-returning one and the composition returns
/// `StructuredActionResult<Int, String>`.)
///
/// Unlike a selection, a result is *untagged* on the wire: it encodes as
/// the selected component's bare output. It cannot be keyed by action name
/// — matching-output components collapse into a single case, so a payload
/// no longer identifies which action produced it — and nothing requires it
/// to be: the caller of a tool knows which action it selected. The static
/// `schema` is accordingly a `oneOf` of the payload schemas, and `encode`
/// is real and total; `decode` throws — an untagged union cannot be decoded
/// unambiguously, and nothing decodes outputs.
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

  public func encode(to encoder: inout StructuredEncoder) throws {
    switch self {
    case .first(let output): try output.encode(to: &encoder)
    case .next(let output): try output.encode(to: &encoder)
    }
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    throw StructuredActionCompositionCodingError.resultDecodingIsUnsupported
  }

}

// MARK: - Composition Schema

/// The concrete `Schema` of `StructuredActionSelection` and
/// `StructuredActionResult`: a public wrapper around the internal
/// `MetaSchema` the builder assembles. It exists solely because a composed
/// action's stored schemas — and the `InputSchema` slot of a tool
/// definition publishing one — must be *public*, while `MetaSchema` itself
/// is deliberately internal.
///
/// Unlike `MetaSchema.SchemaCodable` there is no deferred-capture laziness:
/// that type erases arbitrary encodables mid-assembly (where eager encoding
/// would recurse); this one wraps an already-assembled value, so it stores
/// and forwards directly.
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

  /// The wrapper's own schema erases to the `{}` any-schema, like every
  /// reified schema document's.
  public static var schema: some StructuredCodingSchema {
    MetaSchema.any(description: nil)
  }

  public func encode(to encoder: inout StructuredEncoder) throws {
    try wrapped.encode(to: &encoder)
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let wrapped = try await MetaSchema.decode(from: &decoder, in: context)
    try await accessor.initializeValue(to: Self(wrapping: wrapped))
  }

}

// MARK: - Coding Errors

enum StructuredActionCompositionCodingError: Error {
  /// A selection's wire coding is keyed by action names, which are
  /// fold-time values living on the composition, not on the payload types
  /// the selection is generic over; dispatch (a later round) codes
  /// selections through the composed action.
  case selectionCodingRequiresComposition
  /// A result is an untagged union on the wire; it encodes but cannot be
  /// decoded unambiguously, and nothing decodes outputs.
  case resultDecodingIsUnsupported
}

// MARK: - Builder

extension StructuredAction {

  /// The result builder behind `StructuredAction.build`'s trailing closure:
  /// one action stays a leaf `StructuredAction` (the identity build), and
  /// each fold produces a composed action — a plain `StructuredAction`
  /// whose `Input` nests `StructuredActionSelection` pairwise, mirroring
  /// the fold. Nothing is erased, so the composed shape follows the
  /// components by overload resolution on each fold:
  ///
  /// - `Output` stays the components' output type while every component
  ///   agrees, and becomes a nested `StructuredActionResult` on the first
  ///   mismatch. The same-type-constrained overloads are strictly more
  ///   specialized than the mismatch overloads, so Swift prefers
  ///   collapsing whenever it can.
  /// - `SyncInput` follows the same rule: folding only synchronous actions
  ///   composes synchronously — `SyncInput` is the selection itself and
  ///   the synchronous `invoke` dispatches for real — while one `async`
  ///   component anywhere makes the composition async-only
  ///   (`SyncInput == Never`).
  /// - `Failure` distinguishes only non-throwing from throwing: a fold of
  ///   non-throwing components (`Failure == Never` throughout) stays
  ///   non-throwing, while any throwing component anywhere collapses the
  ///   composition to `any Error` — typed failures are not preserved,
  ///   however the components' failures mix. Preserving them is
  ///   expressible, but each preserved shape doubles the overload matrix
  ///   (the `Never`/`any Error` split already does, once); the untyped
  ///   throw is the accepted trade.
  /// - An accumulated *composition* is recognized by its `Input` being a
  ///   `StructuredActionSelection` (the all-sync overloads additionally
  ///   require `SyncInput` to be that same selection): those overloads
  ///   splice the next action into the accumulated keyed enumeration
  ///   rather than starting a fresh two-key object. They too are more
  ///   specialized than the leaf-fold overloads, so they win for
  ///   compositions.
  ///
  /// The fold is where an action's `description` enters a schema — each
  /// keyed input property carries its action's input schema with the
  /// action description prepended. Output schemas are assembled without
  /// descriptions: a matched-output composition stores the plain
  /// `Output.schema` (per-branch use-site descriptions don't survive the
  /// collapse), and a mismatched one stores the `oneOf` of the components'
  /// stored output schemas. (A lone action's `inputSchema` never folds its
  /// description in — it travels separately, in a request's tool
  /// `description` field, say.) Nesting the builder in `StructuredAction`
  /// inherits `Callee`, keeping every component's callee pinned to the
  /// tool's; the outer shape parameters are dead — callers pin them with
  /// placeholders and the builder methods are generic over each
  /// component's own shape.
  ///
  /// Deliberately no `buildBlock`, `buildOptional`, `buildEither`, or
  /// `buildArray`: a conditional action would silently change the wire
  /// schema, so control flow in the closure should not compile. An empty
  /// closure failing with a missing-`buildPartialBlock` diagnostic is the
  /// accepted trade.
  ///
  /// The folding overloads precondition that action names are unique — a
  /// composed enumeration is keyed by name, so duplicates cannot be
  /// represented. Macro-generated tools can never trip this (the macro
  /// diagnoses duplicates at expansion); it guards hand-written builders.
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

    /// Builds the two-key enumeration folding two leaves, prepending each
    /// action's description to its keyed input schema.
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

    /// Splices one further action into an already-assembled enumeration.
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

    /// The `oneOf` of two output schemas, nesting the way
    /// `StructuredActionResult` nests. The stored (instance) schemas are
    /// used so baked-in output descriptions survive; no action description
    /// is folded in — those describe the keyed *inputs*.
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

/// The extension's same-type constraints resolve the *base* type's generic
/// parameters — the way `Task<Never, Never>.sleep` pins `Task`'s — so call
/// sites spell `StructuredAction.build { ... }` with no generic arguments;
/// the result's own parameters are inferred from the closure body's actions.
extension StructuredAction
where
  Callee == Never,
  Input == StructuredEmptyObject,
  Output == StructuredEmptyObject,
  SyncInput == Never,
  Failure == Never
{

  /// The sole public entry point for composing a tool's actions — the
  /// `@StructuredTool` macro's generated `Definition` container and
  /// hand-written conformances alike:
  ///
  /// ```swift
  /// let actions = StructuredAction.build {
  ///   StructuredAction(name: "double", invoke: { ... })
  ///   StructuredAction(name: "shout", invoke: { ... })
  /// }
  /// ```
  ///
  /// One action stays a leaf; several fold into a composed action whose
  /// input nests `StructuredActionSelection` and whose output and failure
  /// collapse or nest per the fold rules (see `Builder`) — either way the
  /// result is a `StructuredAction`, so this one generic signature covers
  /// both. The stored `let`'s initializer infers the concrete result type,
  /// so it is never spelled.
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
