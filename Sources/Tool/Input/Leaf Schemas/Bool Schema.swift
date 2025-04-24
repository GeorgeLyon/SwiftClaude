extension ToolInput {

  public static func schema(
    representing _: Bool.Type = Bool.self
  ) -> some ToolInput.Schema<Bool> {
    BoolSchema()
  }

}

extension Bool: ToolInput.SchemaCodable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}
// MARK: - Implementation Details

private struct BoolSchema: LeafSchema {

  typealias Value = Bool

  let type = "boolean"

}
