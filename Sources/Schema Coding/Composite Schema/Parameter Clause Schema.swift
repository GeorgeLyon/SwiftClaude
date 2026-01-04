private import SchemaCodingSupport

// MARK: - Parameter Clause Result Types

extension SchemaCoding.Support {

  /// Object-style result for labeled parameters
  public struct ParameterClauseObject<
    each Property: ObjectProperty
  > {
    public typealias Value = (repeat (each Property).Value)

    let properties: (repeat ParameterClauseObjectProperty<each Property>)
  }

  /// Tuple-style result for unlabeled parameters
  public struct ParameterClauseTuple<
    each ElementSchema: SchemaCoding.Schema
  > {
    public typealias Value = (repeat (each ElementSchema).Value)

    let elements: (repeat TupleSchemaElement<each ElementSchema>)
  }

}

// MARK: - Parameter Wrapper Types

extension SchemaCoding.Support {

  /// Wrapper for labeled parameter (object property)
  public struct ParameterClauseObjectProperty<
    Property: ObjectProperty
  > {

    init<T>(
      property: Property
    ) where Property == DirectObjectProperty<T> {
      self.objectProperty = property
      self.effectiveSchema = property.propertySchema
    }

    init(
      property: Property,
      effectiveSchema: Property.EffectiveSchema
    ) {
      self.objectProperty = property
      self.effectiveSchema = effectiveSchema
    }

    let objectProperty: Property
    let effectiveSchema: Property.EffectiveSchema
  }

  /// Wrapper for unlabeled parameter (tuple element)
  public struct ParameterClauseTupleElement<
    Schema: SchemaCoding.Schema
  > {
    let schema: Schema
  }

}

// MARK: - Parameter Functions

extension SchemaCoding.Support {

  /// Create a labeled parameter (becomes object property)
  public static func parameter<
    Schema: SchemaCoding.Schema
  >(
    label: SchemaCodingKey,
    schema: Schema
  ) -> ParameterClauseObjectProperty<
    some ObjectProperty<Schema.Value>
  > {
    ParameterClauseObjectProperty(
      property: DirectObjectProperty(
        name: label,
        schema: schema
      )
    )
  }

  /// Create a labeled optional parameter
  public static func parameter<
    Schema: SchemaCoding.Schema
  >(
    label: SchemaCodingKey,
    schema: OptionalSchema<Schema>
  ) -> ParameterClauseObjectProperty<
    some ObjectProperty<Schema.Value?>
  > {
    ParameterClauseObjectProperty(
      property: OptionalObjectProperty(
        name: label,
        schema: schema
      ),
      effectiveSchema: schema
    )
  }

  /// Create a labeled parameter with complex schema (type-erased)
  public static func parameter<
    Schema: SchemaCoding.Schema & ComplexSchema
  >(
    label: SchemaCodingKey,
    schema: Schema
  ) -> ParameterClauseObjectProperty<
    some ObjectProperty<Schema.Value>
  > {
    ParameterClauseObjectProperty(
      property: DirectObjectProperty(
        name: label,
        schema: schema.typeErased()
      )
    )
  }

  /// Create an unlabeled parameter (becomes tuple element)
  public static func parameter<Schema>(
    schema: Schema
  ) -> ParameterClauseTupleElement<Schema> {
    ParameterClauseTupleElement(
      schema: schema
    )
  }

  /// Create an unlabeled parameter with complex schema (type-erased)
  public static func parameter<Schema: SchemaCoding.Schema & ComplexSchema>(
    schema: Schema
  ) -> ParameterClauseTupleElement<TypeErasedSchema<Schema.Value>> {
    ParameterClauseTupleElement(
      schema: schema.typeErased()
    )
  }

}

// MARK: - Parameter Clause Schema Builder

extension SchemaCoding.Support {

  @resultBuilder
  public struct ParameterClauseSchemaBuilder {

    /// Empty -> Empty Object
    public static func buildBlock() -> ParameterClauseObject<> {
      ParameterClauseObject(properties: ())
    }

    /// Start Object (labeled first)
    public static func buildPartialBlock<Property>(
      first: ParameterClauseObjectProperty<Property>
    ) -> ParameterClauseObject<Property> {
      ParameterClauseObject(properties: first)
    }

    /// Start Tuple (unlabeled first)
    public static func buildPartialBlock<Element>(
      first: ParameterClauseTupleElement<Element>
    ) -> ParameterClauseTuple<Element> {
      ParameterClauseTuple(
        elements: TupleSchemaElement(schema: first.schema)
      )
    }

    /// Object + Property = Object
    public static func buildPartialBlock<
      each Property,
      NextProperty
    >(
      accumulated: ParameterClauseObject<
        repeat each Property
      >,
      next: ParameterClauseObjectProperty<
        NextProperty
      >
    ) -> ParameterClauseObject<
      repeat each Property,
      NextProperty
    > {
      ParameterClauseObject(
        properties: (repeat each accumulated.properties, next)
      )
    }

    /// Object + Element = Tuple
    public static func buildPartialBlock<
      each Property,
      NextElementSchema
    >(
      accumulated: ParameterClauseObject<
        repeat each Property
      >,
      next: ParameterClauseTupleElement<
        NextElementSchema
      >
    ) -> ParameterClauseTuple<
      repeat (each Property).EffectiveSchema,
      NextElementSchema
    > {
      ParameterClauseTuple(
        elements: (
          repeat (each accumulated.properties).tupleElement,
          TupleSchemaElement(schema: next.schema)
        )
      )
    }

    /// Tuple + Element = Tuple
    public static func buildPartialBlock<
      each ElementSchema,
      NextElementSchema
    >(
      accumulated: ParameterClauseTuple<repeat each ElementSchema>,
      next: ParameterClauseTupleElement<NextElementSchema>
    ) -> ParameterClauseTuple<repeat each ElementSchema, NextElementSchema> {
      ParameterClauseTuple(
        elements: (
          repeat each accumulated.elements,
          TupleSchemaElement(schema: next.schema)
        )
      )
    }

    /// Tuple + Property = Tuple
    public static func buildPartialBlock<
      each ElementSchema,
      NextProperty
    >(
      accumulated: ParameterClauseTuple<repeat each ElementSchema>,
      next: ParameterClauseObjectProperty<NextProperty>
    ) -> ParameterClauseTuple<repeat each ElementSchema, NextProperty.EffectiveSchema> {
      ParameterClauseTuple(
        elements: (
          repeat each accumulated.elements,
          next.tupleElement
        )
      )
    }

  }

}

extension SchemaCoding.Support.ParameterClauseObjectProperty {
  fileprivate var tupleElement: SchemaCoding.Support.TupleSchemaElement<Property.EffectiveSchema> {
    SchemaCoding.Support.TupleSchemaElement(
      description: objectProperty.name.stringValue,
      schema: effectiveSchema,
    )
  }
}
