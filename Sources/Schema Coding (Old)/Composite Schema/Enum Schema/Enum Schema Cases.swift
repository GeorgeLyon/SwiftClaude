// MARK: - Cases

extension SchemaCoding.Support {

  public static func enumSchemaCase<Value, CaseName>(
    name: CaseName,
    description: String? = nil,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesObject<EmptyCodingKey>,
    finishDecoding: @escaping @Sendable () -> Value
  ) -> EnumSchemaCase<
    Value,
    CaseName,
    _TupleObjectSchema<EmptyCodingKey>
  > {
    let _ = associatedValues()
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: objectSchema(
        description: description,
      ),
      finishDecoding: { values in
        finishDecoding()
      }
    )
  }

  public static func enumSchemaCase<Value, CaseName, PropertyName, each Property>(
    name: CaseName,
    description: String? = nil,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesObject<
      PropertyName,
      repeat each Property
    >,
    finishDecoding: @escaping @Sendable (repeat (each Property).PropertyValue) -> Value
  ) -> EnumSchemaCase<
    Value,
    CaseName,
    _TupleObjectSchema<PropertyName, repeat each Property>
  > {
    let associatedValues = associatedValues()
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: objectSchema(
        description: description,
        properties: repeat each associatedValues.properties
      ),
      finishDecoding: { values in
        finishDecoding(repeat each values)
      }
    )
  }

  public static func enumSchemaCase<Value, CaseName, each ElementSchema>(
    name: CaseName,
    description: String? = nil,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesTuple<repeat each ElementSchema>,
    finishDecoding: @escaping @Sendable (repeat (each ElementSchema).Value) -> Value
  ) -> EnumSchemaCase<
    Value,
    CaseName,
    _TupleSchema<repeat each ElementSchema>
  > {
    let associatedValues = associatedValues()
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: tupleSchema(
        description: description,
        elements: repeat each associatedValues.elementSchemas
      ),
      finishDecoding: { values in
        finishDecoding(repeat each values)
      }
    )
  }

  public static func enumSchemaCase<Value, CaseName, AssociatedValuesSchema>(
    name: CaseName,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesTuple<AssociatedValuesSchema>,
    finishDecoding: @escaping @Sendable (AssociatedValuesSchema.Value) -> Value
  ) -> EnumSchemaCase<
    Value,
    CaseName,
    AssociatedValuesSchema
  > {
    let associatedValues = associatedValues()
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValues.elementSchemas,
      finishDecoding: finishDecoding
    )
  }

  public struct EnumSchemaCase<
    Value: Sendable,
    CaseName: CodingKey,
    AssociatedValuesSchema: Schema
  >: Sendable {

    let name: CaseName
    let associatedValuesSchema: AssociatedValuesSchema
    let finishDecoding: @Sendable (AssociatedValuesSchema.Value) -> Value

  }

}

extension SchemaCoding.Support {

  @resultBuilder
  public enum EnumSchemaCasesBuilder<Value: Sendable, CaseName: CodingKey> {

    public static func buildBlock() -> EnumSchemaCases<Value, CaseName> {
      EnumSchemaCases()
    }

    public static func buildPartialBlock<Schema>(
      first: EnumSchemaCase<Value, CaseName, Schema>
    ) -> EnumSchemaCases<Value, CaseName, Schema> {
      EnumSchemaCases(first)
    }

    public static func buildPartialBlock<each Schema, NextSchema>(
      accumulated: EnumSchemaCases<Value, CaseName, repeat each Schema>,
      next: EnumSchemaCase<Value, CaseName, NextSchema>
    ) -> EnumSchemaCases<Value, CaseName, repeat each Schema, NextSchema> {
      EnumSchemaCases(repeat each accumulated.cases, next)
    }

  }

  public struct EnumSchemaCases<
    Value: Sendable,
    CaseName: CodingKey,
    each AssociatedValueSchema: SchemaCoding.Schema
  >: Sendable {
    let cases: (repeat EnumSchemaCase<Value, CaseName, each AssociatedValueSchema>)

    fileprivate init(
      _ cases: repeat EnumSchemaCase<Value, CaseName, each AssociatedValueSchema>
    ) {
      self.cases = (repeat each cases)
    }

  }

}

// MARK: - Associated Values

extension SchemaCoding.Support {

  public protocol EnumSchemaCaseAssociatedValues {
    associatedtype Value
  }

  public struct EnumSchemaCaseAssociatedValuesObject<
    PropertyName: CodingKey,
    each Property: ObjectProperty
  >: EnumSchemaCaseAssociatedValues {
    public typealias Value = (repeat (each Property).PropertyValue)

    let properties: (repeat each Property)
  }

  public struct EnumSchemaCaseAssociatedValuesTuple<
    each ElementSchema: SchemaCoding.Schema
  >: EnumSchemaCaseAssociatedValues {
    public typealias Value = (repeat (each ElementSchema).Value)

    let elementSchemas: (repeat each ElementSchema)
  }

}

// MARK: - Associated Value

extension SchemaCoding.Support {

  public static func enumSchemaCaseAssociatedValue<
    Label: CodingKey,
    Schema: SchemaCoding.Schema
  >(
    label: Label,
    schema: Schema
  ) -> EnumSchemaCaseAssociatedValuesObjectProperty<
    _RequiredObjectProperty<Label, Schema>
  > {
    EnumSchemaCaseAssociatedValuesObjectProperty(
      objectProperty: objectProperty(
        name: label,
        schema: schema
      )
    )
  }

  public static func enumSchemaCaseAssociatedValue<
    Label: CodingKey,
    Schema: SchemaCoding.Schema
  >(
    label: Label,
    schema: OptionalSchema<Schema>
  ) -> EnumSchemaCaseAssociatedValuesObjectProperty<
    _OptionalObjectProperty<Label, Schema>
  > {
    EnumSchemaCaseAssociatedValuesObjectProperty(
      objectProperty: objectProperty(
        name: label,
        schema: schema
      )
    )
  }

  public static func enumSchemaCaseAssociatedValue<Schema>(
    schema: Schema
  ) -> EnumSchemaCaseAssociatedValuesTupleElement<Schema> {
    EnumSchemaCaseAssociatedValuesTupleElement(
      schema: schema
    )
  }

  public struct EnumSchemaCaseAssociatedValuesObjectProperty<
    Property: ObjectProperty
  > {
    fileprivate let objectProperty: Property
  }

  public struct EnumSchemaCaseAssociatedValuesTupleElement<
    Schema: SchemaCoding.Schema
  > {
    fileprivate let schema: Schema
  }

  @resultBuilder
  public struct EnumSchemaCaseAssociatedValuesBuilder {

    /// Empty Object
    public static func buildBlock() -> EnumSchemaCaseAssociatedValuesObject<
      EmptyCodingKey
    > {
      EnumSchemaCaseAssociatedValuesObject(properties: ())
    }

    /// Start Object
    public static func buildPartialBlock<Property>(
      first: EnumSchemaCaseAssociatedValuesObjectProperty<Property>
    ) -> EnumSchemaCaseAssociatedValuesObject<Property.Name, Property> {
      EnumSchemaCaseAssociatedValuesObject(properties: first.objectProperty)
    }

    /// Start Tuple
    public static func buildPartialBlock<Element>(
      first: EnumSchemaCaseAssociatedValuesTupleElement<Element>
    ) -> EnumSchemaCaseAssociatedValuesTuple<Element> {
      EnumSchemaCaseAssociatedValuesTuple(
        elementSchemas: first.schema
      )
    }

    /// Object + Property = Object
    public static func buildPartialBlock<
      PropertyName,
      each Property,
      NextProperty
    >(
      accumulated: EnumSchemaCaseAssociatedValuesObject<
        PropertyName,
        repeat each Property
      >,
      next: EnumSchemaCaseAssociatedValuesObjectProperty<
        NextProperty
      >
    ) -> EnumSchemaCaseAssociatedValuesObject<
      PropertyName,
      repeat each Property,
      NextProperty
    >
    where NextProperty.Name == PropertyName {
      EnumSchemaCaseAssociatedValuesObject(
        properties: (repeat each accumulated.properties, next.objectProperty)
      )
    }

    /// Tuple + Element = Tuple
    public static func buildPartialBlock<
      each ElementSchema,
      NextElementSchema: SchemaCoding.Schema
    >(
      accumulated: EnumSchemaCaseAssociatedValuesTuple<repeat each ElementSchema>,
      next: EnumSchemaCaseAssociatedValuesTupleElement<NextElementSchema>
    ) -> EnumSchemaCaseAssociatedValuesTuple<repeat each ElementSchema, NextElementSchema> {
      EnumSchemaCaseAssociatedValuesTuple(
        elementSchemas: (repeat each accumulated.elementSchemas, next.schema)
      )
    }

  }

}
