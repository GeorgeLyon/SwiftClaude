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
      self.data = Base64EncodedData(rawData: data)
    }

    private let type = "base64"
    private let mediaType: MediaType

    private struct Base64EncodedData: Encodable {
      let rawData: Data
      func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawData.base64EncodedString())
      }
    }
    private let data: Base64EncodedData

  }

}
