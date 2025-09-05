public import struct Foundation.Data

public struct ImageBlock: Encodable, Sendable {

  public init(source: MediaSource.Base64) {
    self.source = source
  }

  public let type = "image"

  public let source: MediaSource.Base64

}

public struct MediaType: ExpressibleByStringLiteral, RawRepresentable, Encodable, Sendable {

  public enum image {
    public static var jpeg: MediaType { "image/jpeg" }
    public static var png: MediaType { "image/png" }
    public static var gif: MediaType { "image/gif" }
    public static var webp: MediaType { "image/webp" }
  }

  public func encode(to encoder: any Encoder) throws {
    try rawValue.encode(to: encoder)
  }

  public init(stringLiteral value: StringLiteralType) {
    self.rawValue = value
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
  public let rawValue: String

}

public enum MediaSource {

  public struct Base64: Encodable, Sendable {

    public init(
      mediaType: MediaType,
      data: Data
    ) {
      self.mediaType = mediaType
      self.data = data
    }

    public let mediaType: MediaType
    public let data: Data

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKey.self)
      try container.encode("base64", forKey: .type)
      try container.encode(mediaType, forKey: .mediaType)
      try container.encode(data.base64EncodedString(), forKey: .data)
    }

    private enum CodingKey: Swift.CodingKey {
      case type, mediaType, data
    }

  }

}
