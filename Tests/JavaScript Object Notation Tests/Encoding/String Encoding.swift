import Testing

@testable import JavaScriptObjectNotation

@Suite
struct StringEncoding {

  @Test
  func emptyString() {
    let result = encode { stream in
      stream.encode("")
    }
    #expect(result == #""""#)
  }

  @Test
  func simpleString() {
    let result = encode { stream in
      stream.encode("hello")
    }
    #expect(result == #""hello""#)
  }

  @Test
  func stringWithSpaces() {
    let result = encode { stream in
      stream.encode("hello world")
    }
    #expect(result == #""hello world""#)
  }

  @Test
  func escapesQuotes() {
    let result = encode { stream in
      stream.encode(#"say "hi""#)
    }
    #expect(result == #""say \"hi\"""#)
  }

  @Test
  func escapesBackslash() {
    let result = encode { stream in
      stream.encode(#"a\b"#)
    }
    #expect(result == #""a\\b""#)
  }

  @Test
  func escapesNewline() {
    let result = encode { stream in
      stream.encode("a\nb")
    }
    #expect(result == #""a\nb""#)
  }

  @Test
  func escapesTab() {
    let result = encode { stream in
      stream.encode("a\tb")
    }
    #expect(result == #""a\tb""#)
  }

  @Test
  func escapesCarriageReturn() {
    let result = encode { stream in
      stream.encode("a\rb")
    }
    #expect(result == #""a\rb""#)
  }

  @Test
  func escapesBackspace() {
    let result = encode { stream in
      stream.encode("a\u{08}b")
    }
    #expect(result == #""a\bb""#)
  }

  @Test
  func escapesFormFeed() {
    let result = encode { stream in
      stream.encode("a\u{0C}b")
    }
    #expect(result == #""a\fb""#)
  }

  @Test
  func escapesControlCharacters() {
    let result = encode { stream in
      stream.encode("\u{01}")
    }
    #expect(result == #""\u0001""#)
  }

  @Test
  func escapesNullByte() {
    let result = encode { stream in
      stream.encode("\u{00}")
    }
    #expect(result == #""\u0000""#)
  }

  @Test
  func escapesControlCharacter1F() {
    let result = encode { stream in
      stream.encode("\u{1F}")
    }
    #expect(result == #""\u001F""#)
  }

  @Test
  func multipleEscapes() {
    let result = encode { stream in
      stream.encode("a\n\tb")
    }
    #expect(result == #""a\n\tb""#)
  }

  @Test
  func unicodeContent() {
    let result = encode { stream in
      stream.encode("café")
    }
    #expect(result == #""café""#)
  }

  @Test
  func emoji() {
    let result = encode { stream in
      stream.encode("😀")
    }
    #expect(result == #""😀""#)
  }

  @Test
  func utf8Encoding() {
    let utf8Bytes: [UInt8] = Array("hello".utf8)
    let result = encode { stream in
      stream.encode(utf8: utf8Bytes)
    }
    #expect(result == #""hello""#)
  }

}
