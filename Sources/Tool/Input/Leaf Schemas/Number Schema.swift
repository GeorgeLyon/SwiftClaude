import JSONSupport

extension ToolInput {

  public static func schema<T: ToolInput.SchemaCodable & BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable>(
    representing _: T.Type = T.self
  ) -> some Schema<T> {
    NumberSchema()
  }

}

extension Float: ToolInput.SchemaCodable {}
extension Float16: ToolInput.SchemaCodable {}
extension Double: ToolInput.SchemaCodable {}

// MARK: - Implementation Details

extension ToolInput.SchemaCodable where Self: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

private struct NumberSchema<Value: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable>: LeafSchema {

  let type = "number"
  
  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ()
  ) throws -> JSON.DecodingResult<Value> {
    try stream.decodeNumber().map { try $0.decode() }
  }

}
