import Testing

@testable import JavaScriptObjectNotation

@Suite
struct NumberDecoding {

  @Test
  func integer() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("  42".utf8)
      /// It is possible more digits are added to the end of the stream, so we can't return a result yet.
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 42)
    }
  }

  @Test
  func negativeInteger() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("-1".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == -1)
    }
  }

  @Test
  func zero() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("0".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 0)
    }
  }

  @Test
  func decimal() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Double.self)
    } stream: { session in
      session.stream("3.1".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("4".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 3.14)
    }
  }

  @Test
  func negativeDecimal() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Double.self)
    } stream: { session in
      session.stream("-0.5".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == -0.5)
    }
  }

  @Test
  func exponent() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Double.self)
    } stream: { session in
      session.stream("1.5e".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("2".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 150.0)
    }
  }

  @Test
  func negativeExponent() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Double.self)
    } stream: { session in
      session.stream("100e-1".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 10.0)
    }
  }

  @Test
  func exponentAsInteger() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("1e3".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 1000)
    }
  }

  @Test
  func exponentWithPlus() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Double.self)
    } stream: { session in
      session.stream("5E+2".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 500.0)
    }
  }

  @Test
  func streamedInChunks() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Double.self)
    } stream: { session in
      session.stream("  -".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("12".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(".".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("34e".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("-1".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == -1.234)
    }
  }

  @Test
  func decimalWithNegativeExponentNotRepresentableAsInteger() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("10.5e-1".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require {
        try result.get()
      } throws: { error in
        error is DecodingError
      }
    }
  }

  @Test
  func decimalWithNegativeExponentRepresentableAsInteger() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("100.0e-1".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 10)
    }
  }

  @Test
  func decimalWithExponentRepresentableAsInteger() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("10.00e1".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require(result.get() == 100)
    }
  }

  @Test
  func decimalNotRepresentableAsInteger() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("3.14".utf8)
      try #require(!session.isDecodingComplete)
    } onComplete: { result in
      try #require {
        try result.get()
      } throws: { error in
        error is DecodingError
      }
    }
  }

  @Test
  func weirdZeroes() throws {
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("0e-1".utf8)
    } onComplete: { result in
      try #require(result.get() == 0)
    }

    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("-0e-1".utf8)
    } onComplete: { result in
      try #require(result.get() == 0)
    }

    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("-0.5e1".utf8)
    } onComplete: { result in
      try #require(result.get() == -5)
    }

    /// Zero with a non-empty (but all-zero) fractional part and a negative exponent is still 0.
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("0.0e-5".utf8)
    } onComplete: { result in
      try #require(result.get() == 0)
    }

    /// Zero with a non-empty (but all-zero) fractional part and a huge positive exponent is
    /// still 0, and must be recognized in O(1) — not by looping `exponent` times.
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("0.0e9223372036854775807".utf8)
    } onComplete: { result in
      try #require(result.get() == 0)
    }
  }

  @Test
  func zeroWithExponentTooLargeForInt() throws {
    /// Zero is zero regardless of exponent — even when the exponent string is too long to
    /// parse as `Int`. The short-circuit must run before `Int(exponent.stringValue)` is
    /// attempted, otherwise the decoder throws `.numberNotRepresentable` on a value that
    /// is unambiguously 0.
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("0e99999999999999999999999999".utf8)
    } onComplete: { result in
      try #require(result.get() == 0)
    }
  }

  @Test
  func intMinExponentDoesNotTrap() throws {
    /// `Int("-9223372036854775808")` parses to `Int.min`; negating it overflows. The decoder
    /// must throw `.numberNotRepresentable` rather than crashing the process.
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("1e-9223372036854775808".utf8)
    } onComplete: { result in
      try #require {
        try result.get()
      } throws: { error in
        error is DecodingError
      }
    }
  }

  @Test
  func hugePositiveExponentOverflowsQuickly() throws {
    /// A nonzero significand with a huge exponent must throw `.numberNotRepresentable`
    /// after at most `bitWidth` iterations rather than looping `exponent` times.
    try decode { stream in
      try await stream.decodeNumber().decode(as: Int.self)
    } stream: { session in
      session.stream("1e9223372036854775806".utf8)
    } onComplete: { result in
      try #require {
        try result.get()
      } throws: { error in
        error is DecodingError
      }
    }
  }

}
