import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The intermediate representation the macro builds from a decorated declaration.
///
/// `Parsing.swift` lowers Swift syntax into the types in this file, and
/// `Code Generation.swift` raises them back into the `StructuredCoding`
/// conformance. Nothing here touches `SwiftSyntax` traversal or emits members —
/// it is the agreed vocabulary in between, chosen to mirror the hand-written
/// fixtures in `Tests/Structured Coding Tests` (e.g. `MutableStringObject`,
/// `ConstantObject`, the object-properties `Value` enum, `Point`).

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
    /// `StructuredWrapper`. The payload is a one-property `ObjectSchema`
    /// because the wrapper protocol deliberately mirrors `StructuredObject`,
    /// so the same member generation applies; only the conformance differs.
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
  /// core definition through `_StructuredObjectPropertyDefinition` — so the
  /// *type system* decides required vs optional, and `typealias Foo = Bar?`
  /// lowers exactly like `Bar?` — while the presence/kind of a default
  /// (`defaulting`, a fact fully visible in syntax) nests a wrapper around
  /// it, e.g. `StructuredMutableDefaultInitializedPropertyDefinition<
  /// Int._StructuredObjectPropertyDefinition>`.
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
  /// sugar. A bare tuple is not a nominal type, so it can neither conform to
  /// the coding protocols nor carry the `_StructuredObjectPropertyDefinition`
  /// member the property machinery resolves through — generation instead
  /// codes the property through `StructuredTuple`, wrapping in the property
  /// getter and unwrapping (`.values`) in `decode`. Like the `T?` handling,
  /// detection is syntactic but sound: a literal tuple type *is* a tuple by
  /// language definition. A typealias hiding a tuple is not upgraded (and
  /// fails to compile, exactly as it would have without the upgrade).
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

// MARK: - Enumeration Schema

/// A `StructuredEnumeration` conformance.
///
/// Generation emits `Cases` / `cases()` (and, for the non-default coding styles,
/// `codingStyle`), plus any nested `StructuredObject` types synthesized for
/// all-labeled cases. Every `StructuredEnumerationCase` wraps exactly one
/// associated-value type, so each case's 0/1/N Swift associated values are first
/// collapsed onto a single `AssociatedValue`.
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

  var cases: [Case]

  /// The `StructuredEnumerationCodingStyle` the conformance selects.
  /// `objectProperties` is the protocol default, so generation emits no
  /// `codingStyle` member for it; the others emit a `static var codingStyle`.
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
    let associatedValue: AssociatedValue

    /// Carried from `@StructuredCase(description:)`; emitted as the
    /// `description:` argument of the generated `StructuredEnumerationCase`.
    let description: StringLiteralExprSyntax?

  }

}

extension EnumerationSchema.Case {

  /// One Swift associated value of a case: its declared label (if any) and type.
  struct Element {
    /// `nil` when the value is unlabeled (`case pair(Int, String)`).
    let label: TokenSyntax?
    let type: TypeSyntax
  }

  /// How a case's associated values are represented as the single type a
  /// `StructuredEnumerationCase` wraps.
  enum AssociatedValue {

    /// No associated values (`case ping`) — represented by the shared
    /// `StructuredEmptyObject` so the case still codes as an (empty) object.
    case none

    /// Exactly one unlabeled associated value (`case text(String)`,
    /// `case maybe(Int?)`) — its type is used directly.
    case single(Element)

    /// Two or more values with at least one unlabeled (`case pair(Int, String)`,
    /// `case mixed(Int, label: String)`) — wrapped in `StructuredTuple`. Labels
    /// are dropped from the wrapper but kept here for reconstruction.
    case tuple([Element])

    /// One or more values, all labeled (`case circle(radius: Double)`,
    /// `case point(x: Int, y: Int)`) — wrapped in a synthesized
    /// `StructuredObject` whose `rootType` is a unique macro-generated name and
    /// whose properties are these labeled values. A label names an object
    /// property, so a labeled value always codes as an object (which is also
    /// what lets an internally-tagged discriminator live alongside it).
    case object(ObjectSchema)

  }

}

// MARK: - Callable Schema

/// Unchanged from the previous schema format; still consumed by
/// `SchemaCallableMacro` against the legacy `SchemaCoding.Support` API and out of
/// scope for the `StructuredCoding` migration.

struct SchemaType {
  let syntax: TypeSyntax

  enum Kind {
    case optionalTuple([TypeSyntax])
    case tuple([TypeSyntax])
    case other(TypeSyntax)
  }
  let kind: Kind
}

struct SchemaParameter {
  let firstName: TokenSyntax
  let secondName: TokenSyntax?
  let type: SchemaType
  let bindingName: TokenSyntax

  var isLabeled: Bool {
    firstName.tokenKind != .wildcard
  }

  var effectiveName: TokenSyntax {
    secondName ?? firstName
  }

  /// The label to use in parameter() calls - nil if unlabeled
  var label: TokenSyntax? {
    isLabeled ? firstName : nil
  }
}

struct CallableSchema {
  let namespace: StructuredCodingNamespace
  let name: TokenSyntax
  let fullName: String
  let additionalArguments: LabeledExprListSyntax
  let keyConversionStrategy: KeyConversionStrategy
  let parameters: [SchemaParameter]
  let returnType: ReturnType
  let isAsync: Bool
  let throwsClause: ThrowsClauseSyntax?
  let isMethod: Bool

  enum ReturnType {
    case void
    case single(TypeSyntax)
    case tuple([(label: TokenSyntax?, type: TypeSyntax)])
  }
}
