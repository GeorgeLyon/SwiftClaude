@testable import StructuredCoding

/// Reusable `StructuredObject` fixtures shared across the object-decoding test files.
/// Single-use fixtures (constants, defaults, references, nesting wrappers) live
/// privately alongside the tests that exercise them.

// MARK: - Branch A (constructible up front)

/// Two `var` properties, both with initial values (`""` / `nil`), so the object
/// is constructed up front and streams in place — observable mid-stream.
struct MutableStringObject: StructuredObject, Equatable, Sendable {

  var first: String
  var second: String?

  init(first: String, second: String?) {
    self.first = first
    self.second = second
  }

  typealias _FirstProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias _SecondProperty = StructuredObjectProperty<
    Self, StructuredOptionalObjectPropertyDefinition<String>
  >
  typealias Properties = (_FirstProperty, _SecondProperty)
  static func properties() -> Properties {
    (
      _FirstProperty(name: "first", keyPath: \.first),
      _SecondProperty(name: "second", keyPath: \.second)
    )
  }

  typealias ObjectDecoderValues = (
    _FirstProperty.ObjectDecoderValue, _SecondProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(first: objectDecoder.values.0, second: objectDecoder.values.1)
  }
}

/// Two optional `var` properties — both start `nil`, so `{}` is valid and every
/// property may be omitted.
struct OptionalMutableObject: StructuredObject, Equatable, Sendable {

  var a: String?
  var b: String?

  init(a: String?, b: String?) {
    self.a = a
    self.b = b
  }

  typealias _AProperty = StructuredObjectProperty<
    Self, StructuredOptionalObjectPropertyDefinition<String>
  >
  typealias _BProperty = StructuredObjectProperty<
    Self, StructuredOptionalObjectPropertyDefinition<String>
  >
  typealias Properties = (_AProperty, _BProperty)
  static func properties() -> Properties {
    (
      _AProperty(name: "a", keyPath: \.a),
      _BProperty(name: "b", keyPath: \.b)
    )
  }

  typealias ObjectDecoderValues = (
    _AProperty.ObjectDecoderValue, _BProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(a: objectDecoder.values.0, b: objectDecoder.values.1)
  }
}

/// An object with no properties — only `{}` decodes; any property is unknown.
struct EmptyObject: StructuredObject, Equatable, Sendable {

  init() {}

  typealias Properties = ()
  static func properties() -> Properties { () }

  typealias ObjectDecoderValues = ()
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self()
  }
}

// MARK: - Branch B (constructed mid-stream)

/// `a`/`b` (`let Int`) are unavailable up front; `tail` (`var String`) has an
/// initial value (`""`) and streams in once the object exists. Forces the
/// deferred path: buffer → construct mid-stream → stream remaining property.
struct DeferredObject: StructuredObject, Equatable, Sendable {

  let a: Int
  let b: Int
  var tail: String

  init(a: Int, b: Int, tail: String) {
    self.a = a
    self.b = b
    self.tail = tail
  }

  typealias _AProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _BProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _TailProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias Properties = (_AProperty, _BProperty, _TailProperty)
  static func properties() -> Properties {
    (
      _AProperty(name: "a", keyPath: \.a),
      _BProperty(name: "b", keyPath: \.b),
      _TailProperty(name: "tail", keyPath: \.tail)
    )
  }

  typealias ObjectDecoderValues = (
    _AProperty.ObjectDecoderValue,
    _BProperty.ObjectDecoderValue,
    _TailProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(
      a: objectDecoder.values.0,
      b: objectDecoder.values.1,
      tail: objectDecoder.values.2
    )
  }
}

/// The minimal deferred object: a single unavailable property.
struct SingleScalarObject: StructuredObject, Equatable, Sendable {

  let value: Int

  init(value: Int) {
    self.value = value
  }

  typealias _ValueProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias Properties = _ValueProperty
  static func properties() -> Properties {
    _ValueProperty(name: "value", keyPath: \.value)
  }

  typealias ObjectDecoderValues = _ValueProperty.ObjectDecoderValue
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(value: objectDecoder.values)
  }
}
