extension SchemaCoding.Support {

  public typealias _SchemaDescriptionProperty<Name: CodingKey> =
    SchemaCoding.Support._OptionalObjectProperty<
      Name,
      SchemaCoding.Support._ConstantSchema<
        SchemaCoding.Support.OptionalSchema<String.Schema>
      >
    >

}
