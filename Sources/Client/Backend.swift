import struct Foundation.URL

extension ClaudeClient {

  /// A type representing where to send requests to Claude
  public struct Backend: Sendable, Codable {
    public static let production = Backend(kind: .production)

    var apiBase: URL {
      switch kind {
      case .production:
        URL(string: "https://api.anthropic.com")!
      case .custom(let url):
        url
      }
    }

    private enum Kind: Sendable, Codable {
      case production
      case custom(URL)
    }
    private let kind: Kind
  }

}
