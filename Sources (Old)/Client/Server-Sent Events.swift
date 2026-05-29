import HTTPTypes

import struct Foundation.Data

extension ClaudeClient {

  /// Anthropic API-style Server-Sent Events
  /// On top of standard the Server-Sent Event format, this type does some additional processing to simplify downstream API.
  /// Specifically:
  /// - Returned events are decoded as Anthropic-style enums
  /// - `ping` events are ignored
  /// This value also retains `client` to support decoding and so the request won't be cancelled while we are iterating.
  package enum ServerSentEventError: Error {
    case decodingFailure(Error)
    case partialTrailingText(String)
  }
  package struct ServerSentEvents<Event: Decodable>: AsyncSequence {
    package typealias Element = Result<Event, ServerSentEventError>
    package struct AsyncIterator: AsyncIteratorProtocol {

      package mutating func next() async throws -> Element? {
        try await next(isolation: nil)
      }

      package mutating func next(isolation actor: isolated (any Actor)?) async throws -> Element? {
        switch try await events.next(isolation: actor) {
        case .success(let rawEvent):
          do {
            return .success(
              try await client.decode(
                AnthropicEnum<Event>.self,
                fromResponseData: rawEvent.data
              ).wrappedValue
            )
          } catch {
            return .failure(.decodingFailure(error))
          }
        case .failure(.partialTrailingText(let text)):
          return .failure(.partialTrailingText(text))
        case .none:
          return nil
        }
      }

      fileprivate init(
        client: ClaudeClient,
        events: RawServerSentEvents
      ) {
        self.client = client
        self.events =
          events
          /// For convenience, filter `ping` events
          .filter { event in
            guard case .success(let event) = event else {
              return true
            }
            return event.name != "ping"
          }
          .makeAsyncIterator()
      }
      private var client: ClaudeClient
      private var events: AsyncFilterSequence<RawServerSentEvents>.AsyncIterator
    }
    package func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(client: client, events: events)
    }

    init(client: ClaudeClient, body: HTTPTransportResponse.Body) {
      self.client = client
      self.events = RawServerSentEvents(body: body)
    }
    private let client: ClaudeClient
    private let events: RawServerSentEvents

  }

}

// MARK: - Raw Server Sent Events

extension ClaudeClient {

  fileprivate struct RawServerSentEvent {
    let name: String
    let data: Data
  }

  fileprivate enum RawServerSentEventError: Error {
    case partialTrailingText(String)
  }

  /// Raw Server-sent events ignore `ping` events
  fileprivate struct RawServerSentEvents: AsyncSequence {
    typealias Element = Result<RawServerSentEvent, RawServerSentEventError>
    struct AsyncIterator: AsyncIteratorProtocol {

      mutating func next() async throws -> Element? {
        try await next(isolation: nil)
      }

      mutating func next(isolation actor: isolated (any Actor)?) async throws -> Element? {
        guard let eventLine = try await lines.next(isolation: actor) else {
          return nil
        }

        /// We currently don't use the event name for decoding, as the `data:` encodes this information as well.
        let eventName = try eventLine.removePrefix("event: ")

        guard
          let dataLine = try await lines.next(isolation: actor)
        else {
          return .failure(.partialTrailingText("\(eventLine)\n)"))
        }
        let data = try dataLine.removePrefix("data: ")

        guard
          let emptyLine = try await lines.next(isolation: actor),
          emptyLine.isEmpty
        else {
          return .failure(.partialTrailingText("\(eventLine)\n\(dataLine)"))
        }

        /// Uncomment to print server-sent events
        // print("SSE: \(data)")

        return .success(RawServerSentEvent(name: eventName, data: Data(data.utf8)))
      }

      fileprivate init(lines: AsyncLines) {
        self.lines = lines.makeAsyncIterator()
      }
      private var lines: AsyncLines.AsyncIterator

    }
    func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(lines: lines)
    }

    fileprivate init(body: ClaudeClient.HTTPTransportResponse.Body) {
      self.lines = AsyncLines(body: body)
    }
    private let lines: AsyncLines

    private struct PartialTrailingEvent: Error {
      let value: String
    }
  }

}

// MARK: - Async Lines

extension ClaudeClient.RawServerSentEvents {

  /// Swift's `AsyncLineSequence` seems to not be available on Linux, so we roll our own.
  fileprivate struct AsyncLines: AsyncSequence {
    typealias Element = String
    struct AsyncIterator: AsyncIteratorProtocol {

      mutating func next() async throws -> Element? {
        try await next(isolation: nil)
      }

      mutating func next(isolation actor: isolated (any Actor)?) async throws -> Element? {
        /// Check for buffered lines
        if let next = lineReader.readLine() {
          return next
        }
        /// Read segments awaiting a line
        while let segment = try await segments.next(isolation: actor) {
          lineReader.append(segment)
          if let next = lineReader.readLine() {
            return next
          }
        }
        /// All remaining data is now in `lineReader`
        /// If there was a line to read via `readLine` we would have returned from the `while` loop above
        return lineReader.remainder
      }

      fileprivate init(segments: Segments) {
        self.segments = segments.makeAsyncIterator()
      }
      private var segments: Segments.Iterator
      private var lineReader = BufferedLineReader()
    }
    func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(segments: segments)
    }

    fileprivate init(body: ClaudeClient.HTTPTransportResponse.Body) {
      self.segments = body.map { String(decoding: $0, as: UTF8.self) }
    }
    fileprivate typealias Segments = AsyncMapSequence<
      ClaudeClient.HTTPTransportResponse.Body, String
    >
    private let segments: Segments
  }

}

extension ClaudeClient.RawServerSentEvents.AsyncLines {

  private struct BufferedLineReader {

    mutating func readLine() -> String? {
      guard let newlineIndex else {
        return nil
      }

      let completeSegments = segments[..<newlineIndex.segment]
      let partialTrailingSegment = segments[newlineIndex.segment][..<newlineIndex.character]
      let trailingSegmentRemainder = segments[newlineIndex.segment][newlineIndex.character...]
        .dropFirst()
      if trailingSegmentRemainder.isEmpty {
        segments.removeSubrange(...newlineIndex.segment)
      } else {
        segments[newlineIndex.segment] = String(trailingSegmentRemainder)
        segments.removeSubrange(..<newlineIndex.segment)
      }

      return completeSegments.joined() + partialTrailingSegment
    }

    mutating func append(_ segment: String) {
      segments.append(segment)
    }

    var remainder: String? {
      if segments.isEmpty {
        return nil
      } else {
        return segments.joined()
      }
    }

    private typealias Index = (segment: Int, character: String.Index)
    private var newlineIndex: Index? {
      segments
        .lazy
        .enumerated()
        .compactMap { (offset, segment) -> Index? in
          let characterIndex = segment.firstIndex { character in
            switch character {
            case "\r\n", "\n":
              true
            default:
              false
            }
          }
          guard let characterIndex else {
            return nil
          }
          return (offset, characterIndex)
        }
        .first
    }

    private var segments: [String] = []

  }

}

// MARK: - Implementation Details

extension String {
  fileprivate func removePrefix(_ prefix: String) throws -> String {
    guard hasPrefix(prefix) else {
      throw ExpectedPrefix(prefix: prefix, line: self)
    }
    return String(dropFirst(prefix.count))
  }
  private struct ExpectedPrefix: Error {
    let prefix: String
    let line: String
  }
}
