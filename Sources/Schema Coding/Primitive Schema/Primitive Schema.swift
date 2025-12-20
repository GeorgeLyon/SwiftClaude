extension SchemaCoding.Support {

  protocol PrimitiveSchema: Schema {
    init(description: String?)
    var description: String? { get }
    var type: String { get }
  }

}

extension SchemaCoding.Support.PrimitiveSchema {

}

private enum SchemaCodingKey: CodingKey {
  case description
  case type
}
