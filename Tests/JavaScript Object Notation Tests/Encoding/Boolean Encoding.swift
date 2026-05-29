import Testing

@testable import JavaScriptObjectNotation

@Suite
struct BooleanEncoding {

  @Test
  func trueLiteral() {
    let result = encode { stream in
      stream.encode(true)
    }
    #expect(result == "true")
  }

  @Test
  func falseLiteral() {
    let result = encode { stream in
      stream.encode(false)
    }
    #expect(result == "false")
  }

}
