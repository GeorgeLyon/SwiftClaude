import JSONSupport

// MARK: - Case Encoding

extension SchemaCoding {

  public struct TypeUnionCaseEncoder {
    fileprivate let implementation: TypeUnionCaseEncoderImplementationProtocol
  }

  fileprivate protocol TypeUnionCaseEncoderImplementationProtocol {
    func encode(to encoder: inout JSON.EncodingStream)
  }

  fileprivate struct TypeUnionCaseEncoderImplementation<
    Schema: SchemaCoding.Schema
  >: TypeUnionCaseEncoderImplementationProtocol {
    func encode(to stream: inout JSON.EncodingStream) {
      stream.encode(value, using: schema)
    }
    let schema: Schema
    let value: Schema.Value
  }

}

private struct TypeUnionSchema<
  Value,
  NullSchema: SchemaCoding.Schema,
  BoolSchema: SchemaCoding.Schema,
  NumberSchema: SchemaCoding.Schema,
  StringSchema: SchemaCoding.Schema,
  ArraySchema: SchemaCoding.Schema,
  ObjectSchema: SchemaCoding.Schema
>: SchemaCoding.Schema {

  let nullCase: TypeUnionSchemaCase<Value, NullSchema>
  let boolCase: TypeUnionSchemaCase<Value, BoolSchema>
  let numberCase: TypeUnionSchemaCase<Value, NumberSchema>
  let stringCase: TypeUnionSchemaCase<Value, StringSchema>
  let arrayCase: TypeUnionSchemaCase<Value, ArraySchema>
  let objectCase: TypeUnionSchemaCase<Value, ObjectSchema>

  typealias CaseEncoder = @Sendable (
    Value,
    _ nullCase: () -> SchemaCoding.TypeUnionCaseEncoder,
    _ boolCase: () -> SchemaCoding.TypeUnionCaseEncoder,
    _ numberCase: () -> SchemaCoding.TypeUnionCaseEncoder,
    _ stringCase: () -> SchemaCoding.TypeUnionCaseEncoder,
    _ arrayCase: () -> SchemaCoding.TypeUnionCaseEncoder,
    _ objectCase: () -> SchemaCoding.TypeUnionCaseEncoder
  ) -> SchemaCoding.TypeUnionCaseEncoder
  let caseEncoder: CaseEncoder

}

private struct TypeUnionSchemaCase<Value, Schema: SchemaCoding.Schema> {
  let schema: Schema
  let initializer: @Sendable (Schema.Value) -> Value
}
