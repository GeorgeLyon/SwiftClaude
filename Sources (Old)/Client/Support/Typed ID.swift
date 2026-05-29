import struct Foundation.UUID

public protocol TypedID: CustomStringConvertible {
  init(untypedValue: UntypedID)
  var untypedValue: UntypedID { get }
}

extension TypedID {
  public var description: String {
    "\(Self.self):\(untypedValue.stringValue)"
  }
}

extension TypedID where Self: Encodable {
  public func encode(to encoder: any Encoder) throws {
    try untypedValue.encode(to: encoder)
  }
}

extension TypedID where Self: Decodable {
  public init(from decoder: any Decoder) throws {
    self.init(untypedValue: try UntypedID(from: decoder))
  }
}

extension TypedID where Self: Hashable {
  public func hash(into hasher: inout Hasher) {
    untypedValue.stringValue.hash(into: &hasher)
  }
}

extension TypedID where Self: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.untypedValue.stringValue == rhs.untypedValue.stringValue
  }
}

extension TypedID where Self: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(untypedValue: UntypedID(stringValue: value))
  }
}

/// A unique ID
/// This is most likely a UUID, though for some types like messages it has a different format.
/// Users should not use this type directly, other than to implement the `TypedID` protocol.
/// This scopes ID to the type it identifies (like `ToolUse.ID: TypedID`).
/// This is also the reason this type doesn't conform to the `Codable` or `Hashable` protocols, though it theoretically could.
public struct UntypedID: Sendable {

  fileprivate init(stringValue: String) {
    self.stringValue = stringValue
  }

  fileprivate let stringValue: String

  fileprivate init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    /// Unlike in `init(_:UUID)`, we don't lowercase strings coming from the backend to ensure we faithfully represent what the backend sends us.
    stringValue = try container.decode(String.self)
  }

  fileprivate func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(stringValue)
  }

  fileprivate init(_ uuid: UUID) {
    /// Anthropic's API expects lowercase UUIDs
    stringValue = uuid.uuidString.lowercased()
  }

}
