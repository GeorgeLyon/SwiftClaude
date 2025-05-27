import Testing

@testable import JSONSupport

@Suite("Value Tests")
private struct ValueTests {

  @Test func stringTest() async throws {
    var decoder = JSON.ValueDecoder()
    decoder.stream.push("\"Hello, World!\"")
    try decoder.stringDecoder.withDecodedFragments {
      #expect($0 == ["Hello, World!"])
    }
  }

}
