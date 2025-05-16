import HTTPTypes
package import Tool

package import struct Foundation.Data

public actor ClaudeClient {

  public init(
    backend: Backend,
    authenticator: Authenticator
  ) {
    self.init(
      backend: backend,
      authenticator: authenticator,
      httpTransport: URLSessionTransport()
    )
  }

  /// We may end up supporting alternative transport implementations, such as the NIO-based `async-http-client`
  package init(
    backend: Backend,
    authenticator: Authenticator,
    httpTransport: any HTTPTransport
  ) {
    self.authenticator = authenticator
    self.backend = backend
    self.httpTransport = httpTransport
  }

  package enum APIVersion: String {
    case v2023_06_01 = "2023-06-01"
  }

  package enum AnthropicBetaHeader: String {
    case promptCaching_v2024_07_31 = "prompt-caching-2024-07-31"
    case computerUse_v2024_10_22 = "computer-use-2024-10-22"
  }

  package enum Method {
    case post
  }

  /// - Parameters:
  ///   - eventType: A `Decodable` enum that uses a Swift-generated `init(from: Decoder)`
  package func serverSentEvents<Body: Encodable, Event: Decodable>(
    method: Method,
    path: String,
    apiVersion: APIVersion,
    anthropicBetaHeaders: [AnthropicBetaHeader]?,
    body: sending Body,
    eventType: Event.Type = Event.self
  ) async throws -> sending ServerSentEvents<Event> {
    let httpMethod: HTTPRequest.Method =
      switch method {
      case .post: .post
      }

    let response = try await response(
      method: httpMethod,
      path: path,
      apiVersion: apiVersion,
      anthropicBetaHeaders: anthropicBetaHeaders,
      body: body,
      acceptedContentTypes: [.eventStream]
    )
    guard response.http.status == .ok else {
      var chunks: [Data] = []
      for try await chunk in response.body {
        chunks.append(chunk)
      }
      let body = String(decoding: chunks.joined(), as: UTF8.self)

      throw InvalidResponseStatus(
        status: response.http.status,
        body: body
      )
    }

    return ServerSentEvents(client: self, body: response.body)
  }

  package func decode<T: Decodable>(
    _ type: T.Type,
    fromResponseData data: Data
  ) throws -> sending T {
    try responseBodyDecoder.decode(type, from: data)
  }

  package func decodeValue<Schema: ToolInput.Schema>(
    using schema: Schema,
    fromResponseData data: Data
  ) throws -> sending Schema.Value {
    try responseBodyDecoder.decodeValue(using: schema, fromResponseData: data)
  }

  private enum ContentType: String {
    case json = "application/json"
    case eventStream = "text/event-stream"
  }

  private func response<Body: Encodable>(
    method: HTTPRequest.Method,
    path: String,
    apiVersion: APIVersion,
    anthropicBetaHeaders: [AnthropicBetaHeader]?,
    body: sending Body,
    acceptedContentTypes: [ContentType]
  ) async throws -> sending HTTPTransportResponse {

    /// Create the HTTP Request
    let httpRequest: HTTPRequest
    do {
      guard let apiKey = try authenticator.apiKey else {
        throw Unauthenticated()
      }

      let contentType: ContentType
      switch requestBodyEncoder.contentType {
      case .json:
        contentType = .json
      }

      var mutableRequest = HTTPRequest(
        method: method,
        url: backend.apiBase.appending(path: path),
        headerFields: [
          .userAgent: userAgent,
          .anthropic.apiVersion: apiVersion.rawValue,
          .anthropic.apiKey: apiKey.stringValueForHttpHeader,
          .contentType: contentType.rawValue,
          .accept: acceptedContentTypes.map(\.rawValue).joined(separator: ", "),
        ]
      )
      if let anthropicBetaHeaders {
        let value = anthropicBetaHeaders.map(\.rawValue).joined(separator: ", ")
        mutableRequest.headerFields[.anthropic.beta] = value
      }
      httpRequest = mutableRequest
    }

    let response = try await httpTransport.send(
      HTTPTransportRequest(
        http: httpRequest,
        body: try requestBodyEncoder.encode(body)
      ),
      isolation: self
    )
    return response
  }

  private let authenticator: Authenticator
  private let backend: Backend
  private let httpTransport: any HTTPTransport
  private let requestBodyEncoder: RequestBodyEncoder = .anthropic
  private let responseBodyDecoder: ResponseBodyDecoder = .anthropic

  private struct Unauthenticated: Error {

  }
  private struct InvalidResponseStatus: Error {
    let status: HTTPResponse.Status
    let body: String
  }
}

// MARK: - Header Fields

extension HTTPField.Name {
  enum anthropic {
    static let apiVersion = HTTPField.Name("anthropic-version")!
    static let apiKey = HTTPField.Name("x-api-key")!
    static let beta = HTTPField.Name("anthropic-beta")!
  }
}
