import Testing

@testable import JavaScriptObjectNotation

@Suite("Decoder")
struct DecoderTests {

  /// The actor-based decoder runs decoding operations in a genuinely concurrent
  /// context, so `performAsync` executes its operation, including suspensions
  /// that hop to other actors.
  @Test
  func performAsyncExecutesOperation() async throws {
    let decoder = Decoder()
    let counter = Counter()
    let value = try await decoder.decode(from: Array("true".utf8)) { stream in
      let value = try await stream.decodeBoolean()
      let count = try await stream.performAsync {
        await counter.increment()
      }
      #expect(count == 1)
      return value
    }
    #expect(value == true)
  }

  private actor Counter {
    private var count = 0
    func increment() -> Int {
      count += 1
      return count
    }
  }

}
