extension SchemaCoding.Support {

  protocol PrimitiveSchema: Schema {
    init(description: String?)
    var description: String? { get }
    var type: String { get }
  }

}

extension SchemaCoding.Support.PrimitiveSchema {

  public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
    SchemaCoding.Support.SchemaMetadata(
      primitiveRepresentation: description == nil ? type : nil,
      mayAcceptNull: false
    )
  }

  public func metaSchema(
    in context: SchemaCoding.Support.SchemaContext
  ) -> some SchemaCoding.Support.Schema<Self> {
    let objectSchema = SchemaCoding.Support.objectSchema {
      SchemaCoding.Support.objectProperty(
        name: SchemaCodingKey.description,
        constantValue: context.contextualDescription(for: description)
      )
      SchemaCoding.Support.objectProperty(
        name: SchemaCodingKey.type,
        constantValue: type
      )
    }
    return objectSchema.wrap { wrapped in
      Self(description: description)
    } unwrap: { (wrapper: Self) in
      ((), ())
    }
  }

}

private enum SchemaCodingKey: CodingKey {
  case description
  case type
}
