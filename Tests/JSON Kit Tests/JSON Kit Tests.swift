import Foundation
import Testing

@testable import JSONKit

@Suite
private struct JSONKitTests {

  @Test
  func testSomething() async throws {
    let pair = JSON<String.UTF8View>.ByteStream.makeStream()
    let continuation = pair.continuation
    var stream = pair.stream()

    continuation.yield(
      """
      "Hello, World!"
      """.utf8
    )

    try await stream.read("\"")
    var reader = JSON.StringFragmentReader(stream: stream)

    var fragments: [String] = []
    while let fragment = try await reader.readNextFragment() {
      fragments.append(fragment)
    }

    #expect(fragments.joined() == "Hello, World!")
  }
}
