import Testing

@testable import JavaScriptObjectNotation

@Suite
struct OpaqueValueDecoding {

  // MARK: - decodeOpaqueValue()

  @Test
  func null() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("null".utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("null".utf8))
    }
  }

  @Test
  func boolean() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("true".utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("true".utf8))
    }
  }

  @Test
  func number() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("42".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("42".utf8))
    }
  }

  @Test
  func decimal() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("3.14".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("3.14".utf8))
    }
  }

  @Test
  func string() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream(#""hello""#.utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array(#""hello""#.utf8))
    }
  }

  @Test
  func emptyArray() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("[]".utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("[]".utf8))
    }
  }

  @Test
  func array() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("[1, 2, 3]".utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("[1, 2, 3]".utf8))
    }
  }

  @Test
  func emptyObject() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("{}".utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("{}".utf8))
    }
  }

  @Test
  func object() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream(#"{"a": 1, "b": 2}"#.utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array(#"{"a": 1, "b": 2}"#.utf8))
    }
  }

  @Test
  func withLeadingWhitespace() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream("   null".utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array("   null".utf8))
    }
  }

  @Test
  func streamedAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream(#"{"a":"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#" [1, 2]}"#.utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array(#"{"a": [1, 2]}"#.utf8))
    }
  }

  @Test
  func nestedStructure() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue()
    } stream: { session in
      session.stream(#"{"a": [1, true, null]}"#.utf8)
    } onComplete: { result in
      let opaque = try result.get()
      #expect(opaque.bytes == Array(#"{"a": [1, true, null]}"#.utf8))
    }
  }

  // MARK: - decodeOpaqueValue(_:)

  @Test
  func withDecodeNull() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue { stream in
        try await stream.decodeNull()
      }
    } stream: { session in
      session.stream("null".utf8)
    } onComplete: { result in
      let (_, value) = try result.get()
      #expect(value.bytes == Array("null".utf8))
    }
  }

  @Test
  func withDecodeBoolean() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue { stream in
        try await stream.decodeBoolean()
      }
    } stream: { session in
      session.stream("false".utf8)
    } onComplete: { result in
      let (decoded, value) = try result.get()
      #expect(decoded == false)
      #expect(value.bytes == Array("false".utf8))
    }
  }

  @Test
  func withDecodeNumber() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("42".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      let (decoded, value) = try result.get()
      #expect(decoded == 42)
      #expect(value.bytes == Array("42".utf8))
    }
  }

  @Test
  func withDecodeString() throws {
    try decode { stream in
      try await stream.decodeOpaqueValue { stream in
        try await stream.decodeString()
      }
    } stream: { session in
      session.stream(#""hello""#.utf8)
    } onComplete: { result in
      let (decoded, value) = try result.get()
      #expect(decoded == "hello")
      #expect(value.bytes == Array(#""hello""#.utf8))
    }
  }

}
