import Testing

@testable import JavaScriptObjectNotation

@Suite
struct ObjectDecoding {

  @Test
  func emptyObject() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream("{}".utf8)
    }
  }

  @Test
  func emptyObjectWithWhitespace() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream("{  }".utf8)
    }
  }

  @Test
  func singleProperty() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeNumber().decode(as: Int.self))
        }
        #expect(name == "a")
        #expect(value == 1)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"a": 1}"#.utf8)
    }
  }

  @Test
  func multipleProperties() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name1, value1) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeNumber().decode(as: Int.self))
        }
        #expect(name1 == "a")
        #expect(value1 == 1)
        let isAtEnd1 = decoder.isAtEnd
        #expect(!isAtEnd1)

        let (name2, value2) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeNumber().decode(as: Int.self))
        }
        #expect(name2 == "b")
        #expect(value2 == 2)
        let isAtEnd2 = decoder.isAtEnd
        #expect(isAtEnd2)
      }
    } stream: { session in
      session.stream(#"{"a": 1, "b": 2}"#.utf8)
    }
  }

  @Test
  func stringValues() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeString())
        }
        #expect(name == "greeting")
        #expect(value == "hello")
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"greeting": "hello"}"#.utf8)
    }
  }

  @Test
  func leadingWhitespace() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let value = try await decoder.decodeProperty { _, stream in
          try await stream.decodeNumber().decode(as: Int.self)
        }
        #expect(value == 1)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"  {"a": 1}"#.utf8)
    }
  }

  @Test
  func whitespaceAroundProperties() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let value1 = try await decoder.decodeProperty { _, stream in
          try await stream.decodeNumber().decode(as: Int.self)
        }
        #expect(value1 == 1)

        let value2 = try await decoder.decodeProperty { _, stream in
          try await stream.decodeNumber().decode(as: Int.self)
        }
        #expect(value2 == 2)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{ "a" : 1 , "b" : 2 }"#.utf8)
    }
  }

  @Test
  func nestedObject() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, innerValue) = try await decoder.decodeProperty { name, stream in
          let value = try await stream.decodeObject { inner in
            let value = try await inner.decodeProperty { _, stream in
              try await stream.decodeNumber().decode(as: Int.self)
            }
            let isAtEnd = inner.isAtEnd
            #expect(isAtEnd)
            return value
          }
          return (name, value)
        }
        #expect(name == "outer")
        #expect(innerValue == 42)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"outer": {"inner": 42}}"#.utf8)
    }
  }

  @Test
  func objectWithArrayValue() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          let arr = try await stream.decodeArrayElements { stream in
            try await stream.decodeNumber().decode(as: Int.self)
          }
          return (name, arr)
        }
        #expect(name == "nums")
        #expect(value == [1, 2, 3])
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"nums": [1, 2, 3]}"#.utf8)
    }
  }

  @Test
  func objectWithBooleanValue() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeBoolean())
        }
        #expect(name == "flag")
        #expect(value == true)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"flag": true}"#.utf8)
    }
  }

  @Test
  func objectWithNullValue() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        try await decoder.decodeProperty { _, stream in
          try await stream.decodeNull()
        }
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"key": null}"#.utf8)
    }
  }

  @Test
  func streamedInChunks() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeNumber().decode(as: Int.self))
        }
        #expect(name == "a")
        #expect(value == 1)

        let (name2, value2) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeNumber().decode(as: Int.self))
        }
        #expect(name2 == "b")
        #expect(value2 == 2)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"a": 1,"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#" "b": 2}"#.utf8)
    }
  }

  @Test
  func propertySplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeString())
        }
        #expect(name == "key")
        #expect(value == "value")
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(#"{"ke"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"y": "val"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"ue"}"#.utf8)
    }
  }

  @Test
  func bracesSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let value = try await decoder.decodeProperty { _, stream in
          try await stream.decodeNumber().decode(as: Int.self)
        }
        #expect(value == 1)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream("{".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#""a": 1"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream("}".utf8)
    }
  }

  @Test
  func manyChunks() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let (name, value) = try await decoder.decodeProperty { name, stream in
          (name, try await stream.decodeNumber().decode(as: Int.self))
        }
        #expect(name == "a")
        #expect(value == 1)
        let isAtEnd = decoder.isAtEnd
        #expect(isAtEnd)
      }
    } stream: { session in
      session.stream(" ".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("{".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"""#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream("a".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"""#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(":".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("1".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("}".utf8)
    }
  }

  // MARK: - Peek

  @Test
  func peekExistingProperty() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let value = try await decoder.peekObjectProperty(
          matchPropertyName: { stream in
            try await stream.decodeString() == "b"
          },
          peekPropertyValue: { stream in
            try await stream.decodeNumber().decode(as: Int.self)
          }
        )
        #expect(value == 2)
      }
    } stream: { session in
      session.stream(#"{"a": 1, "b": 2, "c": 3}"#.utf8)
    }
  }

  @Test
  func peekMissingProperty() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let value = try await decoder.peekObjectProperty(
          matchPropertyName: { stream in
            try await stream.decodeString() == "missing"
          },
          peekPropertyValue: { stream in
            try await stream.decodeNumber().decode(as: Int.self)
          }
        )
        #expect(value == nil)
      }
    } stream: { session in
      session.stream(#"{"a": 1, "b": 2}"#.utf8)
    }
  }

  @Test
  func peekFirstProperty() throws {
    try decode { stream in
      try await stream.decodeObject { decoder in
        let value = try await decoder.peekObjectProperty(
          matchPropertyName: { stream in
            try await stream.decodeString() == "a"
          },
          peekPropertyValue: { stream in
            try await stream.decodeNumber().decode(as: Int.self)
          }
        )
        #expect(value == 1)
      }
    } stream: { session in
      session.stream(#"{"a": 1, "b": 2}"#.utf8)
    }
  }

}
