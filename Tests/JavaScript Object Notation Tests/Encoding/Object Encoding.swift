import Testing

@testable import JavaScriptObjectNotation

@Suite
struct ObjectEncoding {

  @Test
  func emptyObject() {
    let result = encode { stream in
      stream.encodeObject { _ in }
    }
    #expect(result == "{}")
  }

  @Test
  func singleProperty() {
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty("key") { stream in
          stream.encode("value")
        }
      }
    }
    #expect(result == #"{"key":"value"}"#)
  }

  @Test
  func multipleProperties() {
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty("a") { stream in
          stream.encode(1)
        }
        object.encodeProperty("b") { stream in
          stream.encode(2)
        }
      }
    }
    #expect(result == #"{"a":1,"b":2}"#)
  }

  @Test
  func nestedObjects() {
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty("outer") { stream in
          stream.encodeObject { inner in
            inner.encodeProperty("inner") { stream in
              stream.encode(true)
            }
          }
        }
      }
    }
    #expect(result == #"{"outer":{"inner":true}}"#)
  }

  @Test
  func objectWithArray() {
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty("items") { stream in
          stream.encodeArray { array in
            array.encodeElement { stream in
              stream.encode(1)
            }
            array.encodeElement { stream in
              stream.encode(2)
            }
          }
        }
      }
    }
    #expect(result == #"{"items":[1,2]}"#)
  }

  @Test
  func propertyNameWithSpecialCharacters() {
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty("key with \"quotes\"") { stream in
          stream.encode(1)
        }
      }
    }
    #expect(result == #"{"key with \"quotes\"":1}"#)
  }

  @Test
  func encodePropertyWithEncodeName() {
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty(
          encodeName: { stream in
            stream.encode("custom")
          },
          encodeValue: { stream in
            stream.encode(42)
          }
        )
      }
    }
    #expect(result == #"{"custom":42}"#)
  }

  // MARK: - Pretty Print

  @Test
  func emptyObjectPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeObject { _ in }
    }
    #expect(result == "{\n\n}")
  }

  @Test
  func singlePropertyPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeObject { object in
        object.encodeProperty("key") { stream in
          stream.encode("value")
        }
      }
    }
    #expect(result == "{\n  \"key\": \"value\"\n}")
  }

  @Test
  func multiplePropertiesPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeObject { object in
        object.encodeProperty("a") { stream in
          stream.encode(1)
        }
        object.encodeProperty("b") { stream in
          stream.encode(2)
        }
      }
    }
    #expect(result == "{\n  \"a\": 1,\n  \"b\": 2\n}")
  }

  @Test
  func nestedObjectsPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeObject { object in
        object.encodeProperty("outer") { stream in
          stream.encodeObject { inner in
            inner.encodeProperty("key") { stream in
              stream.encode(1)
            }
          }
        }
      }
    }
    #expect(result == "{\n  \"outer\": {\n    \"key\": 1\n  }\n}")
  }

}
