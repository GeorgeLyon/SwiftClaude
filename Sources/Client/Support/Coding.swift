import Tool
import JSONSupport

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

struct RequestBodyEncoder {

  enum ContentType {
    case json
  }
  nonisolated var contentType: ContentType { .json }

  func encode<T: Encodable>(_ value: T) throws -> Data {
    try encoder.encode(value)
  }

  static var anthropic: Self {
    return Self(encoder: .anthropic)
  }

  private init(encoder: JSONEncoder) {
    self.encoder = encoder
  }
  private let encoder: JSONEncoder

}

struct ResponseBodyDecoder {

  static var anthropic: Self {
    return Self(decoder: .anthropic)
  }

  func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> sending T {
    try decoder.decode(type, from: data)
  }

  func decodeValue<Schema: ToolInput.Schema>(
    using schema: Schema,
    fromResponseData data: Data
  ) throws -> sending Schema.Value {
    var stream = JSON.DecodingStream()
    stream.push(String(decoding: data, as: UTF8.self))
    stream.finish()
    
    var state = schema.initialValueDecodingState
    let result = try schema.decodeValue(from: &stream, state: &state)
    return try result.getValue()
  }

  private init(decoder: JSONDecoder) {
    self.decoder = decoder
  }
  private let decoder: JSONDecoder

}

// MARK: - Configuration

extension JSONDecoder {

  static var anthropic: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

}

extension JSONEncoder {
  static var anthropic: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
  }
}
