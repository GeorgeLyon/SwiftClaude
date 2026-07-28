import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The intermediate representation the macro builds from a decorated
/// declaration: `Parsing.swift` lowers Swift syntax into these types, and
/// `Code Generation.swift` raises them back into the `StructuredCoding`
/// conformance.

// MARK: - Shared

/// A parsed identifier paired with the token it was parsed from, so generation
/// can use either the semantic name or reproduce the original token.
struct IdentifiableToken {
  let identifier: Identifier
  let token: TokenSyntax
  var name: String {
    identifier.name
  }
}

/// Mirror of the library's public `StructuredUndeclaredPropertyBehavior`, as
/// parsed from `@StructuredCodable(undeclaredPropertyBehavior:)`.
enum UndeclaredPropertyBehavior {
  case reject
  case discard
}

/// Mirror of the library's public `StructuredCodingCompatibilityMode` option
/// set, as parsed from `@StructuredCodable(compatibilityMode:)`.
struct CompatibilityModes: OptionSet {
  let rawValue: Int

  /// Access stored properties through getter closures (`getter: { $0.x }`)
  /// instead of key path literals (`keyPath: \.x`), which crash at runtime when
  /// rooted in a pack-generic type. See the doc comment on
  /// `StructuredCodingCompatibilityMode.variadicGenerics`.
  static let variadicGenerics = Self(rawValue: 1 << 0)
}

// MARK: - Structured Codable Type

/// The top-level declaration the macro is attached to, resolved to one of the two
/// `StructuredCoding` shapes it knows how to synthesize.
struct StructuredCodableType {

  let isPublic: Bool

  /// The type syntax for the decorated declaration, with any generic parameters
  /// bound by name (e.g. `Box<Element>`). Used as the conformance's `Self`/`Value`.
  let typeSyntax: TypeSyntax

  enum Kind {
    /// A `struct` or `class` — becomes a `StructuredObject`.
    case object(ObjectSchema)
    /// A single-property `struct` with `style: .wrapper` — becomes a
    /// `StructuredWrapper`.
    case wrapper(ObjectSchema)
    /// An `enum` — becomes a `StructuredEnumeration`.
    case enumeration(EnumerationSchema)
  }
  let kind: Kind

  var namespace: StructuredCodingNamespace {
    switch kind {
    case .object(let schema), .wrapper(let schema): schema.namespace
    case .enumeration(let schema): schema.namespace
    }
  }

}

// MARK: - Object Schema

/// A `StructuredObject` conformance: a JSON object keyed by property name.
///
/// Generation emits the `StructuredObjectProperties` / `properties()` / `ObjectDecoderValues` /
/// `decode(from:)` members; encoding, `initialValueForDecoding`, and the rest are
/// supplied by the `StructuredObject` protocol extension and need no synthesis.
struct ObjectSchema {

  let namespace: StructuredCodingNamespace

  /// The type the generated key paths are rooted in — `"Self"` for the decorated
  /// type, or the synthesized name when this object stands in for an all-labeled
  /// enum case (see `AssociatedValue.object`).
  let rootType: TokenSyntax

  /// Whether generation must also emit the type declaration and its stored
  /// properties (true for a synthesized associated-value object) rather than only
  /// the conformance members on an existing declaration.
  let isSynthesized: Bool

  /// Applied to each property's Swift name to produce its JSON key.
  let keyConversionStrategy: KeyConversionStrategy

  /// Carried from `@StructuredCodable(compatibilityMode:)`. With
  /// `.variadicGenerics`, `properties()` accesses stored properties through
  /// getter closures instead of key path literals.
  let compatibilityModes: CompatibilityModes

  /// Carried from `@StructuredCodable(description:)`. The generated `schema`
  /// witness passes it as `_schema`'s `typeDescription:`; use sites prepend
  /// theirs onto the resulting schema.
  let description: StringLiteralExprSyntax?

  /// Carried from `@StructuredCodable(undeclaredPropertyBehavior:)`, or — for
  /// an object synthesized for an enum case payload — from the enclosing
  /// enumeration's argument. `.discard` emits a `static var
  /// undeclaredPropertyBehavior` witness; `.reject` is the protocol default
  /// and emits nothing.
  var undeclaredPropertyBehavior: UndeclaredPropertyBehavior = .reject

  var properties: [Property]

  struct Property {

    /// The Swift property name, used both for the key path (`\.first`) and the
    /// initializer argument label (`first:`) in `decode(from:)`.
    let name: IdentifiableToken

    /// The wrapper definition and value type, which together pick the
    /// `Structured…ObjectPropertyDefinition` and the decode disposition.
    let definition: Definition

    /// A unique, macro-generated name for the property's
    /// `StructuredObjectProperty` type alias. The fixtures spell these
    /// `_FirstProperty`; the macro replaces them with `makeUniqueName` results to
    /// avoid collisions with user declarations.
    let propertyTypeAliasName: TokenSyntax

    /// Carried from `@StructuredProperty(description:)`; emitted as the
    /// `description:` argument of the generated property descriptor, whose
    /// initializer prepends it onto the property's schema.
    let description: StringLiteralExprSyntax?

  }

}

extension ObjectSchema.Property {

  /// How a stored property is wrapped: the declared type resolves its own
  /// core definition through `_StructuredObjectPropertyDefinition`, and a
  /// default nests a `Structured…DefaultInitializedPropertyDefinition`
  /// wrapper around it.
  struct Definition {
    /// The property's declared type, emitted verbatim.
    let valueType: TypeSyntax
    let defaulting: Defaulting
    /// Present when the declared type is (an optional of) a tuple, which
    /// generation codes through `StructuredTuple`.
    let tupleUpgrade: TupleUpgrade?

    init(valueType: TypeSyntax, defaulting: Defaulting) {
      self.valueType = valueType
      self.defaulting = defaulting
      self.tupleUpgrade = TupleUpgrade(upgrading: valueType)
    }
  }

  /// A property whose declared type is a tuple, possibly wrapped in optional
  /// sugar. Bare tuples cannot conform to the coding protocols, so
  /// generation codes the property through `StructuredTuple` instead.
  struct TupleUpgrade {

    /// `true` for `(Int, Int)?` — the wrap and unwrap lift over the optional
    /// and the property codes through `StructuredTuple<Int, Int>?`.
    let isOptional: Bool

    /// `StructuredTuple`'s generic arguments: the element types with any
    /// labels dropped (tuple values code positionally), or the single pack
    /// expansion of a pack tuple.
    let genericArguments: [TypeSyntax]

    /// `true` for `(repeat each T)`, whose values are wrapped and unwrapped
    /// by pack expansion (`repeat each`) rather than by element index.
    let isPack: Bool

    init?(upgrading declaredType: TypeSyntax) {
      var isOptional = false
      var coreType = declaredType.trimmed
      if let optionalType = coreType.as(OptionalTypeSyntax.self) {
        isOptional = true
        coreType = optionalType.wrappedType
      }
      guard let tupleType = coreType.as(TupleTypeSyntax.self) else {
        return nil
      }
      let elementTypes = tupleType.elements.map { TypeSyntax($0.type.trimmed) }
      let packElementCount = elementTypes.count(where: { $0.is(PackExpansionTypeSyntax.self) })
      switch (elementTypes.count, packElementCount) {
      case (1, 1):
        self.isPack = true
      case (2..., 0):
        self.isPack = false
      default:
        /// `()` is `Void`, `(T)` is just `T` parenthesized, and a tuple
        /// mixing fixed elements with pack expansions cannot be rebuilt
        /// element-wise — none are upgraded.
        return nil
      }
      self.isOptional = isOptional
      self.genericArguments = elementTypes
    }

  }

  /// Whether the property carries a default, and what generation does with it in
  /// `decode(from:)`.
  enum Defaulting {
    /// No initializer — the decoded value is passed straight through
    /// (`label: objectDecoder.values.N`).
    case none
    /// `let x = <default>` — a constant. Wrapped in
    /// `StructuredImmutableDefaultInitializedPropertyDefinition`; omitted from the
    /// `decode` initializer call so the type's own initializer supplies it.
    case immutable
    /// `var x = <default>` — default-initialized. Wrapped in
    /// `StructuredMutableDefaultInitializedPropertyDefinition`; the decoded value
    /// falls back to `defaultValue` when omitted
    /// (`label: objectDecoder.values.N ?? <defaultValue>`).
    case mutable(defaultValue: ExprSyntax)
  }

}

// MARK: - Parameter Clause Schema

/// How a list of labeled/unlabeled typed elements — an enum case's associated
/// values, a function's parameter clause, or a function's tuple return type —
/// collapses onto the single `StructuredCodable` type that represents it.
enum ParameterClauseSchema {

  /// No elements (`case ping`, `func ping()`) — represented by the shared
  /// `StructuredEmptyObject` so the value still codes as an (empty) object.
  case none

  /// Exactly one unlabeled element (`case text(String)`, `func f(_ x: Int?)`)
  /// — its type is used directly.
  case single(Element)

  /// Two or more elements with at least one unlabeled (`case pair(Int, String)`,
  /// `func f(bar: Int, _ x: String)`) — wrapped in `StructuredTuple`. Labels
  /// are dropped from the wrapper but kept here for reconstruction.
  case tuple([Element])

  /// One or more elements, all labeled (`case circle(radius: Double)`,
  /// `func move(x: Int, y: Int)`) — wrapped in a synthesized
  /// `StructuredObject` whose properties are these labeled values.
  case object(ObjectSchema)

  /// One element of the clause: its declared label (if any), type, and default.
  struct Element {
    /// `nil` when the element is unlabeled (`case pair(Int, String)`).
    let label: TokenSyntax?
    let type: TypeSyntax
    /// `= expr` on the element. Honored only in the `.object` collapse, where
    /// it lowers as `Defaulting.mutable` — identical to a `var x: T = expr`
    /// struct property.
    let defaultValue: ExprSyntax?
  }

}

// MARK: - Enumeration Schema

/// A `StructuredEnumeration` conformance.
///
/// Generation emits `Cases` / `cases()` (and, when any component differs from
/// the protocol defaults, `codingConfiguration`), plus any nested
/// `StructuredObject` types synthesized for all-labeled cases. Every
/// `StructuredEnumerationCase` wraps exactly one
/// associated-value type, so each case's 0/1/N Swift associated values are first
/// collapsed onto a single `ParameterClauseSchema`.
struct EnumerationSchema {

  let namespace: StructuredCodingNamespace

  /// The enum type — `"Self"`.
  let typeName: TokenSyntax

  /// Applied to each case's Swift name to produce its discriminator string.
  let keyConversionStrategy: KeyConversionStrategy

  /// Carried from `@StructuredCodable(compatibilityMode:)`. With
  /// `.variadicGenerics`, the synthesized associated-value objects (which
  /// inherit these modes) access their properties through getter closures
  /// instead of key path literals.
  let compatibilityModes: CompatibilityModes

  let codingStyle: CodingStyle

  /// See `ObjectSchema.description`.
  let description: StringLiteralExprSyntax?

  /// Carried from `@StructuredCodable(undeclaredPropertyBehavior:)`. Recorded
  /// in the generated `codingConfiguration` and propagated into every
  /// synthesized case payload object; a case whose single associated value is
  /// a user-declared object type keeps that type's own setting.
  var undeclaredPropertyBehavior: UndeclaredPropertyBehavior = .reject

  /// The shared zero-property payload object synthesized for the enum's
  /// value-less cases when `undeclaredPropertyBehavior` is `.discard` — the
  /// shared `StructuredEmptyObject` cannot carry a per-enum setting. `nil`
  /// (falling back to `StructuredEmptyObject`) otherwise, or when no case
  /// needs it.
  var emptyCasePayloadObject: ObjectSchema? = nil

  var cases: [Case]

  /// The `StructuredEnumerationCodingStyle` the conformance selects — the
  /// `style` component of the generated `codingConfiguration`.
  /// `objectProperties` is the protocol default, so (with a default
  /// undeclared-property behavior) generation emits no configuration member
  /// for it.
  enum CodingStyle {
    /// `{"caseName": <associatedValue>}` — the default.
    case objectProperties
    /// A single object whose `discriminatorPropertyName` names the case and whose
    /// remaining properties are the associated `StructuredObject`.
    case internallyTagged(discriminatorPropertyName: StringLiteralExprSyntax)
    /// A bare value whose JSON *kind* names the case
    /// (`StructuredEnumerationCodingStyleTypeDiscriminated`).
    case typeDiscriminated
  }

  struct Case {

    /// The case name, used as the `case` selector, the reconstruction
    /// (`.text($0)`), and — after key conversion — the discriminator string.
    let name: IdentifiableToken

    /// The single type the case's associated values collapse onto.
    let associatedValue: ParameterClauseSchema

    /// Carried from `@StructuredCase(description:)`; emitted as the
    /// `description:` argument of the generated `StructuredEnumerationCase`.
    let description: StringLiteralExprSyntax?

  }

}

// MARK: - Callable Schema

/// A function decorated with `@StructuredAction`, lowered to what
/// `@StructuredTool`'s generation needs: the parameter clause and return type
/// collapsed onto their `ParameterClauseSchema` representations, plus the
/// effects and callee that pick the `StructuredAction` generic arguments.
struct CallableSchema {

  let namespace: StructuredCodingNamespace

  let isPublic: Bool

  /// The function's base name (`foo`) — also the runtime action name, which
  /// tools dispatch on (which is why a tool's action names must be unique).
  let baseName: TokenSyntax

  /// The tool type the action is invoked on, always spelled by name:
  /// covariant `Self` cannot appear in a non-top-level position on actors
  /// and classes, so naming the type uniformly keeps one code path for every
  /// declaration kind.
  let calleeType: TypeSyntax

  /// The parameter clause, collapsed onto the action's `Input`.
  let input: ParameterClauseSchema

  /// The return type, collapsed onto the action's `Output`.
  let output: ParameterClauseSchema

  /// `true` adds `async` to the glue closure and pins `SyncInput` to `Never`.
  let isAsync: Bool

  /// `true` when the decorated function is isolated to an actor callee — an
  /// instance method of an actor without `nonisolated`. Invoking it from the
  /// glue closure's nonisolated context requires `await`, so the closure is
  /// forced async and `SyncInput` pinned to `Never` even when the function
  /// itself is synchronous.
  let isCalleeIsolated: Bool

  /// Whether the glue closure is async: the function's own `async`, or the
  /// actor hop an isolated callee forces.
  var isEffectivelyAsync: Bool { isAsync || isCalleeIsolated }

  /// The action's `Failure` type.
  enum Failure {
    /// Non-throwing — `Never`.
    case never
    /// `throws(E)` — `E`.
    case typed(TypeSyntax)
    /// Bare `throws` — `any Error`.
    case untyped
  }
  let failure: Failure

  /// Carried from `@StructuredAction(description:inputDescription:outputDescription:)`,
  /// emitted as the corresponding arguments of the generated initializer call.
  let description: StringLiteralExprSyntax?
  let inputDescription: StringLiteralExprSyntax?
  let outputDescription: StringLiteralExprSyntax?

}
