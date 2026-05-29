import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

@Suite("Probe")
struct ProbeSuite {

  // Feed a prefix that ends on `,"` two ways and report session.result.
  @Test func probeCommaQuoteBoundary() throws {
    let prefix = #"{"move":{"x":1,"#

    func run(label: String, chunks: [String]) {
      let decoder = IncrementalDecoder()
      let box = BoxAccessor2<ProbeValue>()
      let session = decoder.startDecoding { stream in
        try await stream.withDecoder { d in
          try await ProbeValue.decode(from: &d, in: StructuredDecodingContext(), using: box)
        }
        try await stream.readTrailingWhitespace()
        return try box.value
      }
      for c in chunks {
        session.stream(c.utf8)
      }
      switch session.result {
      case .some(.failure(let e)): print("[\(label)] FAILURE: \(e)")
      case .some(.success): print("[\(label)] SUCCESS")
      case .none: print("[\(label)] still in progress (no result)")
      }
      session.streamingComplete()
    }

    _ = prefix
    let full = #"{"move":{"x":1,"y":2}}"#
    run(label: "all-at-once", chunks: [full])
    run(label: "byte-at-a-time", chunks: full.map { String($0) })
    run(label: "two-chunk-comma-quote", chunks: [#"{"move":{"x":1,"#, #"y":2}}"#])
    run(label: "two-chunk-mid-name", chunks: [#"{"move":{"x"#, #":1,"y":2}}"#])
    run(label: "two-chunk-after-colon", chunks: [#"{"move":{"x":1,"y":"#, #"2}}"#])
  }
}

private final class BoxAccessor2<Value>: StructuredAccessor {
  var value: Value { get throws { guard let s = stored else { throw JavaScriptObjectNotation.DecodingError.decodingIncomplete }; return s } }
  var isMutable: Bool { true }
  func initializeValue(to value: consuming sending Value) async throws { stored = value }
  func accessValue<Delta, T>(applying delta: sending Delta, apply: @Sendable (borrowing Value, sending Delta) async throws -> sending T) async throws -> sending T {
    guard let s = stored else { throw AccessorError.uninitializedValue }
    return try await apply(s, delta)
  }
  func mutateValue<Delta, T>(applying delta: sending Delta, apply: @Sendable (inout Value, sending Delta) async throws -> sending T) async throws -> sending T {
    guard var v = stored else { throw AccessorError.uninitializedValue }
    defer { stored = v }
    return try await apply(&v, delta)
  }
  private var stored: Value?
}

private enum ProbeValue: StructuredEnumeration, Equatable, Sendable {
  case move(ProbeMove)
  typealias Cases = StructuredEnumerationCase<Self, ProbeMove>
  static func cases() -> Cases {
    StructuredEnumerationCase(name: "move", accessor: { v in guard case .move(let a) = v else { return nil }; return a }, initializer: { .move($0) })
  }
}

private struct ProbeMove: StructuredObject, Equatable, Sendable {
  let x: Int
  let y: Int
  init(x: Int, y: Int) { self.x = x; self.y = y }
  typealias Properties = (
    StructuredObjectProperty<Self, StructuredRequiredObjectPropertyDefinition<Int>>,
    StructuredObjectProperty<Self, StructuredRequiredObjectPropertyDefinition<Int>>
  )
  static func properties() -> Properties {
    (StructuredObjectProperty(name: "x", keyPath: \.x), StructuredObjectProperty(name: "y", keyPath: \.y))
  }
  typealias ObjectDecoderValues = (Int, Int)
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(x: objectDecoder.values.0, y: objectDecoder.values.1)
  }
}
