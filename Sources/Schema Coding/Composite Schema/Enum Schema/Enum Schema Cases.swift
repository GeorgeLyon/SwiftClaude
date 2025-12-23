// MARK: - Cases

extension SchemaCoding {

  public typealias EnumDecoder = Support.EnumDecoder

}

extension SchemaCoding.Support {

  public static func enumSchemaCase<Value>(
    name: SchemaCodingKey,
    description: String? = nil,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesObject<>,
    finishDecoding: @escaping () -> Value
  ) -> EnumSchemaCase<
    Value,
    some ObjectSchema<Void>
  > {
    let _ = associatedValues()
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: ConcreteObjectSchema(
        description: description,
        properties: TupleObjectSchemaProperties()
      ),
      finishDecoding: finishDecoding
    )
  }

  public static func enumSchemaCase<Value, each Property>(
    name: SchemaCodingKey,
    description: String? = nil,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesObject<
      repeat each Property
    >,
    finishDecoding: @escaping (EnumDecoder<repeat (each Property).Value>) -> Value
  ) -> EnumSchemaCase<
    Value,
    some ObjectSchema<(repeat (each Property).Value)>
  > {
    let associatedValues = associatedValues()
    let associatedValuesSchema = ConcreteObjectSchema(
      description: description,
      properties: TupleObjectSchemaProperties(repeat each associatedValues.properties)
    )
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValuesSchema,
      finishDecoding: { associatedValues in
        finishDecoding(EnumDecoder(repeat each associatedValues))
      }
    )
  }

  public static func enumSchemaCase<Value, each ElementSchema>(
    name: SchemaCodingKey,
    description: String? = nil,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesTuple<repeat each ElementSchema>,
    finishDecoding: @escaping (EnumDecoder<repeat (each ElementSchema).Value>) -> Value
  ) -> EnumSchemaCase<
    Value,
    some Schema<(repeat (each ElementSchema).Value)>
  > {
    let associatedValues = associatedValues()
    let associatedValuesSchema = TupleSchema(
      description: description,
      elementSchemas: repeat each associatedValues.elementSchemas
    )
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValuesSchema,
      finishDecoding: { associatedValues in
        finishDecoding(EnumDecoder(repeat each associatedValues))
      }
    )
  }

  public static func enumSchemaCase<Value, AssociatedValuesSchema>(
    name: SchemaCodingKey,
    @EnumSchemaCaseAssociatedValuesBuilder
    associatedValues: () -> EnumSchemaCaseAssociatedValuesTuple<AssociatedValuesSchema>,
    finishDecoding: @escaping (AssociatedValuesSchema.Value) -> Value
  ) -> EnumSchemaCase<
    Value,
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
    Value,
    AssociatedValuesSchema: Schema
  > {

    let name: SchemaCodingKey
    let associatedValuesSchema: AssociatedValuesSchema
    let finishDecoding: (AssociatedValuesSchema.Value) -> Value

  }

  public struct EnumDecoder<each AssociatedValue> {
    public let associatedValues: (repeat each AssociatedValue)
    init(_ associatedValues: repeat each AssociatedValue) {
      self.associatedValues = (repeat each associatedValues)
    }
  }

}

extension SchemaCoding.Support {

  @resultBuilder
  public enum EnumSchemaCasesBuilder<Value> {

    public static func buildBlock() -> EnumSchemaCases<Value> {
      EnumSchemaCases()
    }

    public static func buildPartialBlock<Schema>(
      first: EnumSchemaCase<Value, Schema>
    ) -> EnumSchemaCases<Value, Schema> {
      EnumSchemaCases(first)
    }

    public static func buildPartialBlock<each Schema, NextSchema>(
      accumulated: EnumSchemaCases<Value, repeat each Schema>,
      next: EnumSchemaCase<Value, NextSchema>
    ) -> EnumSchemaCases<Value, repeat each Schema, NextSchema> {
      EnumSchemaCases(repeat each accumulated.cases, next)
    }

  }

  public struct EnumSchemaCases<
    Value,
    each AssociatedValueSchema: SchemaCoding.Schema
  > {
    let cases: (repeat EnumSchemaCase<Value, each AssociatedValueSchema>)

    fileprivate init(
      _ cases: repeat EnumSchemaCase<Value, each AssociatedValueSchema>
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
    each Property: ObjectProperty
  >: EnumSchemaCaseAssociatedValues {
    public typealias Value = (repeat (each Property).Value)

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
    Schema: SchemaCoding.Schema
  >(
    label: SchemaCodingKey,
    schema: Schema
  ) -> EnumSchemaCaseAssociatedValuesObjectProperty<
    some ObjectProperty<Schema.Value>
  > {
    EnumSchemaCaseAssociatedValuesObjectProperty(
      objectProperty: RequiredObjectProperty(
        name: label,
        schema: schema
      )
    )
  }

  public static func enumSchemaCaseAssociatedValue<
    Schema: SchemaCoding.Schema
  >(
    label: SchemaCodingKey,
    schema: OptionalSchema<Schema>
  ) -> EnumSchemaCaseAssociatedValuesObjectProperty<
    some ObjectProperty<Schema.Value?>
  > {
    EnumSchemaCaseAssociatedValuesObjectProperty(
      objectProperty: OptionalObjectProperty(
        name: label,
        schema: schema.wrappedSchema
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
    public static func buildBlock() -> EnumSchemaCaseAssociatedValuesObject<> {
      EnumSchemaCaseAssociatedValuesObject(properties: ())
    }

    /// Start Object
    public static func buildPartialBlock<Property>(
      first: EnumSchemaCaseAssociatedValuesObjectProperty<Property>
    ) -> EnumSchemaCaseAssociatedValuesObject<Property> {
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
      each Property,
      NextProperty
    >(
      accumulated: EnumSchemaCaseAssociatedValuesObject<
        repeat each Property
      >,
      next: EnumSchemaCaseAssociatedValuesObjectProperty<
        NextProperty
      >
    ) -> EnumSchemaCaseAssociatedValuesObject<
      repeat each Property,
      NextProperty
    > {
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
