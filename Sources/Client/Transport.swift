package import HTTPTypes

package import struct Foundation.Data

extension ClaudeClient {

  /// The actual underlying mechanism for sending HTTP Requests
  /// We use `package` visibility so that we can change the API without affecting the public API
  package protocol HTTPTransport {

    func send(
      _ request: Request,
      isolation: isolated any Actor
    ) async throws -> sending Response

  }

  package struct HTTPTransportRequest {
    init(http: HTTPRequest, body: Data?) {
      self.http = http
      self.body = body

      /// Uncomment to print the request
      print("REQUEST: \(String(decoding: body!, as: UTF8.self))")
    }
    package let http: HTTPRequest
    package let body: Data?
  }

  /// `package` visibility because this leaks some implementation details (like `holdOnto`)
  /// Also this theoretically shouldn't need to be `Sendable` since it is `sending` everywhere.
  /// Unfortunately the compiler seems to get confused, possibly related to this issue:
  /// https://forums.swift.org/t/isolating-an-inout-parameter/75095/12
  package struct HTTPTransportResponse: Sendable {

    package typealias Body = AsyncThrowingStream<Data, Error>
    package init(http: HTTPResponse, body: Body, holdOnto: Any) {
      self.http = http
      self.body = body
      self.holdOnto = HoldOnto(holdOnto)
    }
    let http: HTTPResponse
    let body: Body

    /// `Sendable` because we don't actually do anything with the held value
    private struct HoldOnto: @unchecked Sendable {
      init(_ value: Any) {
        self.value = value
      }
      private let value: Any
    }
    private let holdOnto: HoldOnto

  }

}

extension ClaudeClient.HTTPTransport {

  package typealias Request = ClaudeClient.HTTPTransportRequest

  package typealias Response = ClaudeClient.HTTPTransportResponse

}
