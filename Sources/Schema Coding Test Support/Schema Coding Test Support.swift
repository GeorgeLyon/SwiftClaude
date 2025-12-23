public import Testing

@testable import JSONSupport
@testable public import SchemaCoding

// MARK: - Equatable

extension SchemaCoding.Schema where Value: Equatable {

  public func test(
    _ value: Value,
    isCodedAs expectedJSONFragments: JSONFragments,
    prettyPrint: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    try test(
      value,
      isCodedAs: expectedJSONFragments,
      prettyPrint: prettyPrint,
      testEquality: { decoded, expected, sourceLocation in
        #expect(decoded == expected, sourceLocation: sourceLocation)
        return decoded == expected
      },
      sourceLocation: sourceLocation
    )
  }

  public func test(
    _ jsonFragments: JSONFragments,
    decodesAs value: Value,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    try test(
      jsonFragments,
      decodesAs: value,
      testEquality: { decoded, expected, sourceLocation in
        #expect(decoded == expected, sourceLocation: sourceLocation)
        return decoded == expected
      },
      sourceLocation: sourceLocation
    )
  }

}

// MARK: - Tuples

extension SchemaCoding.Schema {

  @_disfavoredOverload
  public func test<each Element: Equatable>(
    _ value: (repeat each Element),
    isCodedAs expectedJSONFragments: JSONFragments,
    prettyPrint: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where Value == (repeat each Element) {
    try test(
      (repeat each value),
      isCodedAs: expectedJSONFragments,
      prettyPrint: prettyPrint,
      testEquality: { decoded, expected, sourceLocation in
        var isEqual = true
        func process<T: Equatable>(_ a: T, _ b: T) {
          #expect(a == b, sourceLocation: sourceLocation)
          if a != b {
            isEqual = false
          }
        }
        repeat process(each decoded, each expected)
        return isEqual
      },
      sourceLocation: sourceLocation
    )
  }

  public func test<
    each FirstElements: Equatable,
    each SecondElements: Equatable
  >(
    _ value: ((repeat each FirstElements), (repeat each (SecondElements))),
    isCodedAs expectedJSONFragments: JSONFragments,
    prettyPrint: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where Value == ((repeat each FirstElements), (repeat each SecondElements)) {
    try test(
      ((repeat each value.0), (repeat each value.1)),
      isCodedAs: expectedJSONFragments,
      prettyPrint: prettyPrint,
      testEquality: { decoded, expected, sourceLocation in
        var isEqual = true
        func process<T: Equatable>(_ a: T, _ b: T) {
          #expect(a == b, sourceLocation: sourceLocation)
          if a != b {
            isEqual = false
          }
        }
        repeat process(each decoded.0, each expected.0)
        repeat process(each decoded.1, each expected.1)
        return isEqual
      },
      sourceLocation: sourceLocation
    )
  }

  public func test<each Element: Equatable>(
    _ jsonFragments: JSONFragments,
    decodesAs value: (repeat each Element),
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws where Value == (repeat each Element) {
    try test(
      jsonFragments,
      decodesAs: (repeat each value),
      testEquality: { decoded, expected, sourceLocation in
        var isEqual = true
        func process<T: Equatable>(_ a: T, _ b: T) {
          #expect(a == b, sourceLocation: sourceLocation)
          if a != b {
            isEqual = false
          }
        }
        repeat process(each decoded, each expected)
        return isEqual
      },
      sourceLocation: sourceLocation
    )
  }

}

// MARK: - Meta Schema

extension SchemaCoding.Schema {

  public func test(
    encodesAs json: String,
    prettyPrint: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    try metaSchema.test(
      self,
      encodesAs: json,
      prettyPrint: prettyPrint,
      sourceLocation: sourceLocation
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Schema {

  public func test(
    _ value: Value,
    encodesAs json: String,
    prettyPrint: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    #expect(throws: Never.self, sourceLocation: sourceLocation) {
      var encoder = SchemaCoding.Support.Encoder()
      if prettyPrint {
        encoder.stream.options = [.prettyPrint]
      }
      encode(value, to: &encoder)
      let encodedJSON = encoder.stream.stringRepresentation
      #expect(encodedJSON == json, sourceLocation: sourceLocation)
    }
  }

  func test(
    _ value: Value,
    isCodedAs expectedJSONFragments: JSONFragments,
    prettyPrint: Bool = false,
    testEquality: (Value, Value, SourceLocation) -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    try test(
      value,
      encodesAs: expectedJSONFragments.fragments.joined(),
      prettyPrint: prettyPrint,
      sourceLocation: sourceLocation
    )

    try test(
      expectedJSONFragments,
      decodesAs: value,
      testEquality: testEquality,
      sourceLocation: sourceLocation
    )
  }

  func test(
    _ jsonFragments: JSONFragments,
    decodesAs value: Value,
    testEquality: (Value, Value, SourceLocation) -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    #expect(throws: Never.self, sourceLocation: sourceLocation) {
      let jsonFragments = jsonFragments.fragments
      let json = jsonFragments.joined()

      /// Test all-at-once decoding
      do {
        var decoder = SchemaCoding.Support.Decoder()
        var decodingState = beginDecodingValue(from: decoder)
        decoder.stream.push(jsonFragments.joined())
        decoder.stream.finish()
        let decodedValue = try decodeValue(from: &decoder, state: &decodingState).value
        guard testEquality(decodedValue, value, sourceLocation) else {
          return
        }
      }

      /// Test explicitly chunked decoding
      do {
        var decoder = SchemaCoding.Support.Decoder()
        var decodingState = beginDecodingValue(from: decoder)
        for fragment in jsonFragments.dropLast() {
          decoder.stream.push(fragment)
          let result = try decodeValue(from: &decoder, state: &decodingState)
          #expect(!result.isComplete, sourceLocation: sourceLocation)
          guard !result.isComplete else {
            return
          }
        }

        decoder.stream.push(jsonFragments.last!)
        decoder.stream.finish()
        let decodedValue = try decodeValue(from: &decoder, state: &decodingState).value
        guard testEquality(decodedValue, value, sourceLocation) else {
          return
        }
      }

      /// Test character-at-a-time decoding
      do {
        var decoder = SchemaCoding.Support.Decoder()
        var decodingState = beginDecodingValue(from: decoder)
        for character in json.dropLast() {
          decoder.stream.push(String(character))
          let result = try decodeValue(from: &decoder, state: &decodingState)
          #expect(!result.isComplete, sourceLocation: sourceLocation)
          guard !result.isComplete else {
            return
          }
        }
        decoder.stream.push(String(json.last!))
        decoder.stream.finish()
        let decodedValue = try decodeValue(from: &decoder, state: &decodingState).value
        guard testEquality(decodedValue, value, sourceLocation) else {
          return
        }
      }
    }
  }

}

// MARK: - Schema Codable

public func test<Value: SchemaCoding.SchemaCodable & Equatable>(
  _ value: Value,
  isCodedAs expectedJSONFragments: JSONFragments,
  prettyPrint: Bool = false,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try Value.schema.test(
    value,
    isCodedAs: expectedJSONFragments,
    prettyPrint: prettyPrint,
    sourceLocation: sourceLocation
  )
}

public func test<Value: SchemaCoding.SchemaCodable & Equatable>(
  _ jsonFragments: JSONFragments,
  decodesAs value: Value,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try Value.schema.test(
    jsonFragments,
    decodesAs: value,
    sourceLocation: sourceLocation
  )
}

// MARK: - JSON Fragments

public struct JSONFragments: ExpressibleByStringInterpolation, ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: String...) {
    fragments = elements
  }
  public init(stringInterpolation: DefaultStringInterpolation) {
    fragments = [String(stringInterpolation: stringInterpolation)]
  }
  public init(stringLiteral value: String) {
    fragments = [value]
  }
  let fragments: [String]
}

// MARK: - Internal API

extension SchemaCoding.Support.DecodingResult {

  fileprivate var isComplete: Bool {
    if case .decoded = kind {
      return true
    } else {
      return false
    }
  }

  fileprivate var value: Value {
    get throws {
      switch kind {
      case .incomplete:
        throw Error.decodingIncomplete
      case .decoded(let value):
        return value
      }
    }
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case decodingIncomplete
}
