extension ToolInput {

  public static func schema<T: ToolInput.SchemaCodable & BinaryInteger & Codable & Sendable>(
    representing _: T.Type = T.self
  ) -> some Schema<T> {
    IntegerSchema()
  }

}

extension Int: ToolInput.SchemaCodable {}
extension Int8: ToolInput.SchemaCodable {}
extension Int16: ToolInput.SchemaCodable {}
extension Int32: ToolInput.SchemaCodable {}
extension Int64: ToolInput.SchemaCodable {}

extension UInt: ToolInput.SchemaCodable {}
extension UInt8: ToolInput.SchemaCodable {}
extension UInt16: ToolInput.SchemaCodable {}
extension UInt32: ToolInput.SchemaCodable {}
extension UInt64: ToolInput.SchemaCodable {}

// MARK: - Implementation Details

extension ToolInput.SchemaCodable where Self: BinaryInteger & Codable & Sendable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

private struct IntegerSchema<Value: Codable & Sendable>: LeafSchema {

  let type = "integer"

}
