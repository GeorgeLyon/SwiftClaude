import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct JSONSupportTests {

  @Test
  func testString() async throws {
    var decoder = JSON<
      AsyncStream<[UInt8]>
    >.StreamingDecoder()

    let (stream, continuation) = AsyncStream<[UInt8]>.makeStream()
    decoder.reset(fragments: stream)
    continuation.yield(
      Array(
        """
        "Hello, World!"
        """.utf8
      )
    )
    
    let (readBytes, fragments) = try await decoder.bytesRead { decoder in
      try await decoder.readString { decoder in
        var fragments: [String] = []
        while let next = try await decoder.decodeNextFragment() {
          print("Read: \(next)")
          fragments.append(next)
        }
        return fragments
      }
    }

    #expect(String(String.UnicodeScalarView(readBytes.map(UnicodeScalar.init))) == "\"Hello, World!\"")
    #expect(fragments.joined() == "Hello, World!")
  }
}
