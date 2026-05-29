import Testing

@testable import JavaScriptObjectNotation

@Suite
struct OpaqueValueEncoding {

  @Test
  func number() {
    let opaque = OpaqueValue(bytes: Array("42".utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == "42")
  }

  @Test
  func decimal() {
    let opaque = OpaqueValue(bytes: Array("3.14".utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == "3.14")
  }

  @Test
  func string() {
    let opaque = OpaqueValue(bytes: Array(#""hello""#.utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == #""hello""#)
  }

  @Test
  func null() {
    let opaque = OpaqueValue(bytes: Array("null".utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == "null")
  }

  @Test
  func boolean() {
    let opaque = OpaqueValue(bytes: Array("true".utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == "true")
  }

  @Test
  func array() {
    let opaque = OpaqueValue(bytes: Array("[1, 2, 3]".utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == "[1, 2, 3]")
  }

  @Test
  func object() {
    let opaque = OpaqueValue(bytes: Array(#"{"a": 1}"#.utf8))
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == #"{"a": 1}"#)
  }

  @Test
  func emptyBytes() {
    let opaque = OpaqueValue(bytes: [])
    let result = encode { stream in
      stream.encode(opaque)
    }
    #expect(result == "")
  }

  @Test
  func withinArray() {
    let opaque = OpaqueValue(bytes: Array("42".utf8))
    let result = encode { stream in
      stream.encodeArray { array in
        array.encodeElement { stream in
          stream.encode(opaque)
        }
        array.encodeElement { stream in
          stream.encode(opaque)
        }
      }
    }
    #expect(result == "[42,42]")
  }

  @Test
  func withinObject() {
    let opaque = OpaqueValue(bytes: Array("42".utf8))
    let result = encode { stream in
      stream.encodeObject { object in
        object.encodeProperty("value") { stream in
          stream.encode(opaque)
        }
      }
    }
    #expect(result == #"{"value":42}"#)
  }

}
