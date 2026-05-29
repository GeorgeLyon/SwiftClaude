import Testing

@testable import JavaScriptObjectNotation

@Suite
struct NullEncoding {

  @Test
  func null() {
    let result = encode { stream in
      stream.encodeNull()
    }
    #expect(result == "null")
  }

}
