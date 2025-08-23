extension SchemaCoding.Support {

  struct PropertyDecoders<State, Value: Sendable>: Sequence, ExpressibleByDictionaryLiteral {

    typealias Decoder =
      @Sendable (
        inout SchemaCoding.Support.Decoder,
        inout State
      ) throws -> DecodingResult<Value>

    subscript<Name: CodingKey>(
      name: Name
    ) -> Decoder? {
      get {
        self[Substring(name.stringValue)]
      }
      set {
        self[Substring(name.stringValue)] = newValue
      }
    }

    subscript(
      name: Substring
    ) -> Decoder? {
      get {
        elements[name]
      }
      set {
        if let newValue {
          if elements.updateValue(newValue, forKey: name) != nil {
            assertionFailure()
            elements[name] = { _, _ in
              throw Error.multiplePropertiesWithSameName(String(name))
            }
          }
        } else {
          elements.removeValue(forKey: name)
        }
      }
    }

    init(dictionaryLiteral elements: (Substring, Decoder)...) {
      self.elements = Dictionary(uniqueKeysWithValues: elements)
    }

    func makeIterator() -> [Substring: Decoder].Iterator {
      elements.makeIterator()
    }

    private var elements: [Substring: Decoder] = [:]
  }

}

private enum Error: Swift.Error {
  case multiplePropertiesWithSameName(String)
}
