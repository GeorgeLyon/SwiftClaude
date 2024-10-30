extension ClaudeClient {

  /// A type which provides an API key for authenticating requests
  public protocol Authenticator: Sendable {
    var apiKey: APIKey? {
      get throws
    }
  }

  /// An API key
  public struct APIKey: Sendable, CustomStringConvertible, CustomDebugStringConvertible {

    /// Creates an API key from a `String`
    public init(_ string: String) {
      self.stringValue = string
    }

    /// Deserializes an API key from bytes
    public static func deserialize(_ bytes: some Collection<UInt8>) throws -> Self {
      /// This currently does not throw but may if we choose to add validation
      APIKey(String(decoding: bytes, as: UTF8.self))
    }

    /// Serializes the API key to bytes
    /// Please be very mindful about how you store your API keys.
    /// Failure to protect your API key may result in unwanted charges or rate limiting.
    public var serialized: some Collection<UInt8> {
      stringValue.utf8
    }

    /// A description which does not share the full authentication data
    public var description: String {
      /// Return the key like Console does
      let prefix = stringValue.prefix(15)
      let suffix = stringValue.suffix(4)
      let description = "\(prefix)…\(suffix)"
      return description
    }

    /// A description which does not share the full authentication data
    /// Might not be necessary since we implement `CustomDebugStringConvertible`
    public var debugDescription: String {
      description
    }

    /// Value to be used when authenticating an HTTP request using this key
    var stringValueForHttpHeader: String {
      stringValue
    }

    private let stringValue: String
  }

}
