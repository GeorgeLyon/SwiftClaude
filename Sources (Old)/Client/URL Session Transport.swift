import Foundation
import HTTPTypes
private import HTTPTypesFoundation

#if canImport(FoundationNetworking)
  private import FoundationNetworking
#endif

extension ClaudeClient {

  struct URLSessionTransport: HTTPTransport {

    func send(
      _ request: Request,
      isolation: isolated any Actor
    ) async throws -> sending Response {
      let urlRequest: URLRequest
      do {
        guard var mutableRequest = URLRequest(httpRequest: request.http) else {
          assertionFailure()
          throw InvalidRequest()
          struct InvalidRequest: Error {}
        }
        mutableRequest.httpBody = request.body
        urlRequest = mutableRequest
      }

      let dataTask = session.dataTask(with: urlRequest)
      let delegate = DataTaskDelegate(urlSessionTask: dataTask)
      dataTask.delegate = delegate
      dataTask.resume()
      return try await delegate.response
    }

    private let session = URLSession(configuration: .ephemeral)
  }

}

// MARK: - Delegate

extension ClaudeClient.URLSessionTransport {

  /// `@unchecked` Sendable because `URLSessionTask` is responsible for ensuring accesses to the delegate are serialized
  /// We use a delegate because `URLSession.AsyncBytes` is not available yet on Linux
  fileprivate final class DataTaskDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    func urlSession(
      _ session: URLSession,
      dataTask: URLSessionDataTask,
      didReceive response: URLResponse,
      completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
      guard let httpResponseContinuation else {
        /// Detect multiple response
        assertionFailure()
        return
      }
      self.httpResponseContinuation = nil
      do {
        httpResponseContinuation.yield(try response.httpResponse)
        httpResponseContinuation.finish()
        completionHandler(.allow)
      } catch {
        httpResponseContinuation.finish(throwing: error)
        completionHandler(.cancel)
      }
    }

    func urlSession(
      _ session: URLSession,
      dataTask: URLSessionDataTask,
      didReceive data: Data
    ) {
      guard let responseBodyContinuation else {
        /// Detect receive-after-complete
        assertionFailure()
        return
      }
      responseBodyContinuation.yield(data)
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: (any Error)?
    ) {
      if let httpResponseContinuation {
        self.httpResponseContinuation = nil

        if let error {
          httpResponseContinuation.finish(throwing: error)
        } else {
          /// Task completed with no error, but a response was never returned
          assertionFailure()
          httpResponseContinuation.finish(throwing: NoResponse())
        }

        /// If we are still waiting on a response, no one can be waiting on `responseBodyStream` per the implementation of `response`.
        /// We still clean up `responseBodyContinuation` to be conservative.
      }

      guard let responseBodyContinuation else {
        /// Detect double-complete
        assertionFailure()
        return
      }
      self.responseBodyContinuation = nil
      responseBodyContinuation.finish(throwing: error)
    }

    /// `Response` retains a reference to this delegate
    var response: Response {
      get async throws {
        let response = try await responseTask.value
        return Response(
          http: response.http,
          body: response.body,
          holdOnto: self
        )
      }
    }

    init(urlSessionTask: URLSessionTask) {
      self.urlSessionTask = urlSessionTask

      let httpResponseStream = AsyncThrowingStream<HTTPResponse, Error>.makeStream()
      httpResponseContinuation = httpResponseStream.continuation
      let responseBodyStream = Response.Body.makeStream()
      responseBodyContinuation = responseBodyStream.continuation
      responseTask = Task {
        var response: HTTPResponse?
        for try await httpResponse in httpResponseStream.stream {
          guard response == nil else {
            throw MultipleResponses()
          }
          response = httpResponse
        }
        guard let response else {
          throw NoResponse()
        }
        return (response, responseBodyStream.stream)
      }

    }
    deinit {
      urlSessionTask.cancel()
    }

    /// This reference is only needed so we cancel the task if the delegate gets deinitialized
    private let urlSessionTask: URLSessionTask

    private let responseTask: Task<(http: HTTPResponse, body: Response.Body), Error>

    /// Continuations are set to `nil` once they are finished
    private var httpResponseContinuation: AsyncThrowingStream<HTTPResponse, Error>.Continuation?
    private var responseBodyContinuation: Response.Body.Continuation?

    private struct MultipleResponses: Error {}
    private struct NoResponse: Error {}
  }

}

// MARK: - Implementation Details

extension URLResponse {
  fileprivate var httpResponse: HTTPResponse {
    get throws {
      guard let response = self as? HTTPURLResponse else {
        throw ExpectedHTTPResponse()
      }
      guard let httpResponse = response.httpResponse else {
        throw InvalidHTTPResponse()
      }
      return httpResponse

      struct ExpectedHTTPResponse: Error {}
      struct InvalidHTTPResponse: Error {}
    }
  }
}
