import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct JSONSupportTests {

  @Test
  func simpleTest() async throws {
    try await StringDecoder.decode { decoder in
      decoder.yield(
      """
      "Hello, World!"
      """
      )
      try await #expect(decoder.decodeFragment() == "Hello, World!")
    }
  }
  
  @Test
  func escapeCharacters() async throws {
    try await StringDecoder.decode { decoder in
      decoder.yield(
        """
        "Hello, World\n"
        """
      )
      try await #expect(decoder.decodeFragment() == "Hello, World\n")
    }
    
    /// Add more tests here
      
  }
  
}

// MARK: - Implementation Details

private struct StringDecoder: ~Copyable {
  
  static func decode(
    _ body: (inout StringDecoder) async throws -> Void
  ) async throws {
    var decoder = StringDecoder()
    try await body(&decoder)
  }
  
  private init() {
    var decoder = JSON<AsyncStream<[UInt8]>>.StreamingDecoder()
    
    let fragments = AsyncStream<[UInt8]>.makeStream()
    self.fragmentsContinuation = fragments.continuation
    decoder.reset(fragments: fragments.stream)
    
    let decodedFragments = AsyncThrowingStream<String, Error>.makeStream()
    self.decodedFragments = decodedFragments.stream.makeAsyncIterator()
    Task {
      do {
        try await decoder.readString { decoder in
          while let next = try await decoder.decodeNextFragment() {
            decodedFragments.continuation.yield(next)
          }
        }
        decodedFragments.continuation.finish()
      } catch {
        decodedFragments.continuation.finish(throwing: error)
      }
    }
  }
  
  mutating func decodeFragment() async throws -> String? {
    try await decodedFragments.next()
  }
  
  func yield(_ fragment: String) {
    fragmentsContinuation.yield(Array(fragment.utf8))
  }
  
  private let fragmentsContinuation: AsyncStream<[UInt8]>.Continuation
  private var decodedFragments: AsyncThrowingStream<String, Error>.AsyncIterator
  
}
