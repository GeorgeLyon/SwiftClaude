import Testing

@testable import JavaScriptObjectNotation

@Suite
struct ArrayEncoding {

  @Test
  func emptyArray() {
    let result = encode { stream in
      stream.encodeArray { _ in }
    }
    #expect(result == "[]")
  }

  @Test
  func singleElement() {
    let result = encode { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encode(1)
        }
      }
    }
    #expect(result == "[1]")
  }

  @Test
  func multipleElements() {
    let result = encode { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encode(1)
        }
        array.encodeElement { stream in
          stream.encode(2)
        }
        array.encodeElement { stream in
          stream.encode(3)
        }
      }
    }
    #expect(result == "[1,2,3]")
  }

  @Test
  func mixedTypes() {
    let result = encode { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encode(42)
        }
        array.encodeElement { stream in
          stream.encode("hello")
        }
        array.encodeElement { stream in
          stream.encode(true)
        }
        array.encodeElement { stream in
          stream.encodeNull()
        }
      }
    }
    #expect(result == #"[42,"hello",true,null]"#)
  }

  @Test
  func nestedArrays() {
    let result = encode { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encodeArray { inner in
            inner.encodeElement { stream in
              stream.encode(1)
            }
          }
        }
        array.encodeElement { stream in
          stream.encodeArray { inner in
            inner.encodeElement { stream in
              stream.encode(2)
            }
          }
        }
      }
    }
    #expect(result == "[[1],[2]]")
  }

  // MARK: - Pretty Print

  @Test
  func emptyArrayPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeArray { _ in }
    }
    #expect(result == "[\n\n]")
  }

  @Test
  func singleElementPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encode(1)
        }
      }
    }
    #expect(result == "[\n  1\n]")
  }

  @Test
  func multipleElementsPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encode(1)
        }
        array.encodeElement { stream in
          stream.encode(2)
        }
        array.encodeElement { stream in
          stream.encode(3)
        }
      }
    }
    #expect(result == "[\n  1,\n  2,\n  3\n]")
  }

  @Test
  func nestedArraysPretty() {
    let result = encode(options: .prettyPrint) { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encodeArray { inner in
            inner.encodeElement { stream in
              stream.encode(1)
            }
          }
        }
      }
    }
    #expect(result == "[\n  [\n    1\n  ]\n]")
  }

}
