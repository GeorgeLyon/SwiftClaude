import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum Schema")
struct EnumSchemaTests {

  @Test
  func enumWithSingleCase() throws {
    enum Status: Equatable {
      case active
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: Status.self,
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "active",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            Status.active
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .active:
          let encoding = encoder.encodings.0
          encoder.encode((), using: encoding)
        }
      }
    )

    try schema.test(Status.active, isCodedAs: #"{"active":{}}"#)
  }

  @Test
  func enumWithMultipleCases() throws {
    enum Result: Equatable {
      case success
      case failure
      case pending
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: Result.self,
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "success",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            Result.success
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "failure",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            Result.failure
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "pending",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            Result.pending
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .success:
          let encoding = encoder.encodings.0
          encoder.encode((), using: encoding)
        case .failure:
          let encoding = encoder.encodings.1
          encoder.encode((), using: encoding)
        case .pending:
          let encoding = encoder.encodings.2
          encoder.encode((), using: encoding)
        }
      }
    )

    try schema.test(Result.success, isCodedAs: #"{"success":{}}"#)
    try schema.test(Result.failure, isCodedAs: #"{"failure":{}}"#)
    try schema.test(Result.pending, isCodedAs: #"{"pending":{}}"#)
  }

  @Test
  func enumWithAssociatedValues() throws {
    enum Event: Equatable {
      case empty
      case message(String)
      case error(code: Int, message: String)
      case point(Int, Int)
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: Event.self,
      cases: {
        // No associated values
        SchemaCoding.Support.enumSchemaCase(
          name: "empty",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            Event.empty
          }
        )
        // Single unlabeled associated value
        SchemaCoding.Support.enumSchemaCase(
          name: "message",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<String>) in
            Event.message(decoder.associatedValues)
          }
        )
        // Multiple labeled associated values (object)
        SchemaCoding.Support.enumSchemaCase(
          name: "error",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "code",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "message",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int, String>) in
            Event.error(code: decoder.associatedValues.0, message: decoder.associatedValues.1)
          }
        )
        // Multiple unlabeled associated values (tuple)
        SchemaCoding.Support.enumSchemaCase(
          name: "point",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int, Int>) in
            Event.point(decoder.associatedValues.0, decoder.associatedValues.1)
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .empty:
          let encoding = encoder.encodings.0
          encoder.encode((), using: encoding)
        case .message(let text):
          let encoding = encoder.encodings.1
          encoder.encode(text, using: encoding)
        case .error(let code, let message):
          let encoding = encoder.encodings.2
          encoder.encode((code, message), using: encoding)
        case .point(let x, let y):
          let encoding = encoder.encodings.3
          encoder.encode((x, y), using: encoding)
        }
      }
    )

    try schema.test(Event.empty, isCodedAs: #"{"empty":{}}"#)
    try schema.test(Event.message("hello"), isCodedAs: #"{"message":"hello"}"#)
    try schema.test(Event.error(code: 404, message: "Not found"), isCodedAs: #"{"error":{"code":404,"message":"Not found"}}"#)
    try schema.test(Event.point(10, 20), isCodedAs: #"{"point":[10,20]}"#)
  }

  @Test
  func enumMetaSchema() throws {
    enum APIResponse: Equatable {
      case success(data: String, count: Int)
      case error(code: Int)
      case loading
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: APIResponse.self,
      description: "An API response type",
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "success",
          description: "A successful response",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "data",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "count",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<String, Int>) in
            APIResponse.success(data: decoder.associatedValues.0, count: decoder.associatedValues.1)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "error",
          description: "An error response",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "code",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int>) in
            APIResponse.error(code: decoder.associatedValues)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "loading",
          description: "Loading state",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            APIResponse.loading
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .success(let data, let count):
          let encoding = encoder.encodings.0
          encoder.encode((data, count), using: encoding)
        case .error(let code):
          let encoding = encoder.encodings.1
          encoder.encode(code, using: encoding)
        case .loading:
          let encoding = encoder.encodings.2
          encoder.encode((), using: encoding)
        }
      }
    )

    try schema.test(
      encodesAs: """
        {
          "description": "An API response type",
          "properties": {
            "success": {
              "description": "A successful response",
              "properties": {
                "data": {
                  "type": "string"
                },
                "count": {
                  "type": "integer"
                }
              },
              "required": [
                "data",
                "count"
              ]
            },
            "error": {
              "description": "An error response",
              "properties": {
                "code": {
                  "type": "integer"
                }
              },
              "required": [
                "code"
              ]
            },
            "loading": {
              "description": "Loading state",
              "properties": {

              }
            }
          }
        }
        """,
      prettyPrint: true
    )
  }

}
