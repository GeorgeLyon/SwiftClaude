// MARK: - Group Placeholder Input

/// The `Input`/`Output` marking a *composed* multi-action `StructuredAction`:
/// the `StructuredAction.Builder` folds several leaves into one action at the
/// fixed instantiation
/// `StructuredAction<Callee, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never>`,
/// so a group is not a separate type — consumers classify tools by
/// constraining on `StructuredAction`'s parameters alone (a leaf's real
/// input vs this placeholder). Nothing ever spells the composed type: a
/// definition's stored `actions` infers it from the builder.
///
/// The accepted trade of carrying group-ness in a placeholder rather than a
/// per-component type pack: composed actions on the same callee are
/// *identically typed* — type-level component identity is gone, and the
/// stored assembled schema is the composed action's identity.
///
/// Uninhabited — the stored `Never` makes the struct valueless — so the
/// composed action's invoke closures are statically unreachable
/// (`switch input.never {}`), and never decodable, because no value exists
/// to produce. A composed action never invokes as a whole: dispatch selects
/// a *component* by name and uses its typed invoke.
///
/// Public (with the discouraging underscore) only because it is spelled in
/// the composed instantiation's public generic arguments. Deliberately NOT
/// `StructuredObjectRepresentable`: consumers' static classification relies
/// on a composed action never matching a direct-leaf constraint like
/// `Input: StructuredObjectRepresentable`.
public struct _StructuredActionGroupInput: StructuredCodable {

  let never: Never

  /// Explicitly the concrete wrapper — the whole point of the placeholder:
  /// the composed action's stored `inputSchema: Input.Schema` slot resolves
  /// to a public, in-module-constructible type the builder can put the
  /// assembled enumeration into.
  public typealias Schema = _StructuredActionGroupSchema

  /// Inert and never published — the composed action's *stored* `inputSchema`
  /// carries the real assembled enumeration; this static requirement exists
  /// only to satisfy `StructuredCodable`.
  public static var schema: _StructuredActionGroupSchema {
    _StructuredActionGroupSchema(wrapping: .any(description: nil))
  }

  public func encode(to encoder: inout StructuredEncoder) throws {
    switch never {}
  }

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  /// Never decodable: the type is uninhabited, so there is no value to
  /// decode into. Dispatch never routes here — it decodes a selected
  /// *component*'s input, not the group placeholder.
  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    throw StructuredActionGroupPlaceholderError.placeholderInputIsNotDecodable
  }

}

private enum StructuredActionGroupPlaceholderError: Error {
  case placeholderInputIsNotDecodable
}

// MARK: - Group Schema

/// The concrete schema type of a composed action's stored `inputSchema`: a
/// public wrapper around the internal `MetaSchema` the builder assembles. It
/// exists solely because that stored slot's type — the placeholder input's
/// `Schema` witness — must be *public* (a type witness of a public
/// conformance) and *constructible in this module* (an opaque witness can
/// only be constructed inside its defining declaration, and `MetaSchema`
/// itself is deliberately internal).
///
/// Unlike `MetaSchema.SchemaCodable` there is no deferred-capture laziness:
/// that type erases arbitrary encodables mid-assembly (where eager encoding
/// would recurse); this one wraps an already-assembled value, so it stores
/// and forwards directly.
public struct _StructuredActionGroupSchema {

  init(wrapping wrapped: MetaSchema) {
    self.wrapped = wrapped
  }

  var wrapped: MetaSchema

}

extension _StructuredActionGroupSchema: StructuredCodingSchema {

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

// MARK: - Builder

extension StructuredAction {

  /// The result builder behind `StructuredAction.build`'s trailing closure:
  /// one action stays a leaf `StructuredAction` (the identity build), a
  /// second folds both into a composed action at the placeholder
  /// instantiation, and each further action splices into the composed
  /// enumeration — the accumulated and appended-to composed types are
  /// *identical* (no pack grows), which is what keeps the append overload a
  /// simple splice. The fold is where an action's `description` enters a
  /// schema — each keyed property carries its action's input schema with the
  /// action description prepended. (A lone action's `inputSchema` never
  /// folds its description in — it travels separately, in a request's tool
  /// `description` field, say.) Nesting the builder in `StructuredAction`
  /// inherits `Callee`, keeping every component's callee pinned to the
  /// tool's; the outer shape parameters are dead — callers pin them with
  /// placeholders and the builder methods are generic over each component's
  /// own shape.
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
      accumulated: StructuredAction<Callee, FirstInput, FirstOutput, FirstSyncInput, FirstFailure>,
      next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, NextFailure>
    ) -> StructuredAction<
      Callee, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
    > {
      precondition(
        accumulated.name != next.name,
        "Duplicate action name \"\(next.name)\"; a tool's actions must have unique names"
      )
      return StructuredAction<
        Callee, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
      >(
        groupSchema: .object(
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

    public static func buildPartialBlock<
      NextInput: StructuredCodable,
      NextOutput: StructuredCodable,
      NextSyncInput,
      NextFailure: Error
    >(
      accumulated: StructuredAction<
        Callee, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
      >,
      next: StructuredAction<Callee, NextInput, NextOutput, NextSyncInput, NextFailure>
    ) -> StructuredAction<
      Callee, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
    > {
      var groupSchema = accumulated.inputSchema.wrapped
      for existingName in groupSchema.propertyNames {
        precondition(
          existingName != next.name,
          "Duplicate action name \"\(next.name)\"; a tool's actions must have unique names"
        )
      }
      groupSchema.appendProperty(
        named: next.key,
        schema: next.inputSchema.prependDescription(next.description)
      )
      return StructuredAction<
        Callee, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
      >(
        groupSchema: groupSchema
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
  /// One action stays a leaf; several fold into a composed action (see
  /// `Builder`). The stored `let`'s initializer infers the concrete result
  /// type, so it is never spelled.
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
