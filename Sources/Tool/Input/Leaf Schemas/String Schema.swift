extension ToolInput {

  public static func schema(
    representing _: String.Type = String.self
  ) -> some ToolInput.Schema<String> {
    StringSchema()
  }

}

extension String: ToolInput.SchemaCodable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

// MARK: - Implementation Details

private struct StringSchema: LeafSchema {

  typealias Value = String

  let type = "string"

}
