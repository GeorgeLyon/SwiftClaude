import Foundation

// MARK: - API

@propertyWrapper
public struct AnthropicEnum<
  Value
> {

  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  public let wrappedValue: Value

}

// MARK: - Implementation Details

extension AnthropicEnum: Decodable
where
  Value: Decodable
{

  public init(from decoder: any Swift.Decoder) throws {
    wrappedValue = try Value(
      from: Decoder(
        wrapped: decoder
      )
    )
  }

}

private struct Decoder: Swift.Decoder {

  init(
    wrapped: any Swift.Decoder

  ) {
    self.wrapped = wrapped
  }

  var codingPath: [any CodingKey] {
    wrapped.codingPath
  }

  var userInfo: [CodingUserInfoKey: Any] {
    wrapped.userInfo
  }

  func container<Key: CodingKey>(
    keyedBy type: Key.Type
  ) throws -> Swift.KeyedDecodingContainer<Key> {
    Swift.KeyedDecodingContainer(
      try AnthropicEnumDecodingContainer<Key>(
        decoder: wrapped
      )
    )
  }

  func unkeyedContainer() throws -> any Swift.UnkeyedDecodingContainer {
    throw AnthropicEnumError()
  }

  func singleValueContainer() throws -> any Swift.SingleValueDecodingContainer {
    throw AnthropicEnumError()
  }

  private let wrapped: any Swift.Decoder

}

private struct AnthropicEnumDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {

  /// - note: The coding path is not affected by the ephemeral keys we add, which we believe is the least suprising behavior
  var codingPath: [any CodingKey] {
    nestedDecoder.codingPath
  }

  var allKeys: [Key] {
    soleKey.map { [$0] } ?? []
  }

  func contains(_ key: Key) -> Bool {
    key.stringValue == soleKey?.stringValue
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    throw AnthropicEnumError()
  }

  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    throw AnthropicEnumError()
  }

  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    throw AnthropicEnumError()
  }

  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    throw AnthropicEnumError()
  }

  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    throw AnthropicEnumError()
  }

  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    throw AnthropicEnumError()
  }

  func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    throw AnthropicEnumError()
  }

  func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    throw AnthropicEnumError()
  }

  func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    throw AnthropicEnumError()
  }

  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    throw AnthropicEnumError()
  }

  func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    throw AnthropicEnumError()
  }

  func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    throw AnthropicEnumError()
  }

  func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    throw AnthropicEnumError()
  }

  func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    throw AnthropicEnumError()
  }

  func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    throw AnthropicEnumError()
  }

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    guard key.stringValue == soleKey?.stringValue else {
      throw keyNotFound(key)
    }
    switch nestedDecoderRole {
    case .casePayload:
      throw AnthropicEnumError()
    case .associatedTypePayload:
      return try nestedDecoder.singleValueContainer().decode(type)
    }
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy type: NestedKey.Type,
    forKey key: Key
  ) throws -> Swift.KeyedDecodingContainer<NestedKey> {
    guard key.stringValue == soleKey?.stringValue else {
      throw keyNotFound(key)
    }
    switch nestedDecoderRole {
    case .casePayload:
      return KeyedDecodingContainer(
        AnthropicEnumDecodingContainer<NestedKey>(
          key: NestedKey(stringValue: "_0"),
          associatedTypePayload: nestedDecoder
        )
      )
    case .associatedTypePayload:
      throw AnthropicEnumError()
    }
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> any Swift.UnkeyedDecodingContainer {
    throw AnthropicEnumError()
  }

  func superDecoder() throws -> any Swift.Decoder {
    throw AnthropicEnumError()
  }

  func superDecoder(forKey key: Key) throws -> any Swift.Decoder {
    throw AnthropicEnumError()
  }

  init(
    decoder: Swift.Decoder
  ) throws {
    let container = try decoder.container(keyedBy: TypeDisambiguatorCodingKey.self)

    /// Anthropic APIs provide use case keys, but since the type name is a value `JSONDecoder.keyDecodingStrategy` does not apply.
    let key_string = try container.decode(String.self, forKey: .type)
    let keyString = convertFromSnakeCase(key_string)

    guard let key = Key(stringValue: keyString) else {
      /// This text is what `JSONDecoder` throws when the decoded key doesn't match the enum case
      throw DecodingError.typeMismatch(
        Key.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Invalid number of keys found, expected one."
        )
      )
    }

    self.soleKey = key
    self.nestedDecoderRole = .casePayload
    self.nestedDecoder = decoder
  }

  private init(
    key: Key?,
    associatedTypePayload: Swift.Decoder
  ) {
    self.soleKey = key
    self.nestedDecoderRole = .associatedTypePayload
    self.nestedDecoder = associatedTypePayload
  }

  /// We prefer to define enums with a particlar type, like `case messageStart(MessageStart)`.
  /// For an enum defined this way, Swift will place the `MessageStart` payload under `"_0"`
  private enum NestedDecoderRole {
    case casePayload
    case associatedTypePayload
  }
  private let soleKey: Key?
  private let nestedDecoderRole: NestedDecoderRole
  private let nestedDecoder: Swift.Decoder

  private func keyNotFound(_ key: Key) -> Error {
    DecodingError.keyNotFound(
      key,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "No value associated with key CodingKeys(stringValue: \"\(key.stringValue)\""
      )
    )
  }

}

private enum TypeDisambiguatorCodingKey: Swift.CodingKey {
  case type
}

/// This is thrown when the standard enum decoding does something we don't expect
private struct AnthropicEnumError: Swift.Error {

}

// MARK: - Snake Case Conversion

private func convertFromSnakeCase(_ stringKey: String) -> String {
  /// This logic is lovingly taken from Swift's implemenation in `JSONDecoder`
  /// https://github.com/swiftlang/swift-foundation/blob/33a49e53d4252cd61b8acab896511dfa5484ab70/Sources/FoundationEssentials/JSON/JSONDecoder.swift#L121
  /// It is covered by the `LICENSE.md` file in that project
  /// https://github.com/swiftlang/swift-foundation/blob/33a49e53d4252cd61b8acab896511dfa5484ab70/LICENSE.md
  guard !stringKey.isEmpty else { return stringKey }

  // Find the first non-underscore character
  guard let firstNonUnderscore = stringKey.firstIndex(where: { $0 != "_" }) else {
    // Reached the end without finding an _
    return stringKey
  }

  // Find the last non-underscore character
  var lastNonUnderscore = stringKey.index(before: stringKey.endIndex)
  while lastNonUnderscore > firstNonUnderscore && stringKey[lastNonUnderscore] == "_" {
    stringKey.formIndex(before: &lastNonUnderscore)
  }

  let keyRange = firstNonUnderscore...lastNonUnderscore
  let leadingUnderscoreRange = stringKey.startIndex..<firstNonUnderscore
  let trailingUnderscoreRange = stringKey.index(after: lastNonUnderscore)..<stringKey.endIndex

  let components = stringKey[keyRange].split(separator: "_")
  let joinedString: String
  if components.count == 1 {
    // No underscores in key, leave the word as is - maybe already camel cased
    joinedString = String(stringKey[keyRange])
  } else {
    joinedString = ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
  }

  // Do a cheap isEmpty check before creating and appending potentially empty strings
  let result: String
  if leadingUnderscoreRange.isEmpty && trailingUnderscoreRange.isEmpty {
    result = joinedString
  } else if !leadingUnderscoreRange.isEmpty && !trailingUnderscoreRange.isEmpty {
    // Both leading and trailing underscores
    result =
      String(stringKey[leadingUnderscoreRange]) + joinedString
      + String(stringKey[trailingUnderscoreRange])
  } else if !leadingUnderscoreRange.isEmpty {
    // Just leading
    result = String(stringKey[leadingUnderscoreRange]) + joinedString
  } else {
    // Just trailing
    result = joinedString + String(stringKey[trailingUnderscoreRange])
  }
  return result
}
