import Foundation

@testable import ClaudeToolInput

func decode<T: ToolInput>(
  _ type: T.Type = T.self,
  _ string: String
) throws -> T {
  let decoder = JSONDecoder()
  return try decoder.decode(
    ToolInputDecodableContainer<T>.self,
    from: Data(string.utf8)
  ).toolInput
}

func encode<T: ToolInput>(_ input: T) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  let data = try encoder.encode(ToolInputEncodableContainer(toolInput: input))
  return String(decoding: data, as: UTF8.self)
}

func encode<T: ToolInputSchema>(
  _ schema: T,
  modify: (inout T) -> Void = { _ in }
) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  var mutableSchema = schema
  modify(&mutableSchema)
  let data = try encoder.encode(
    ToolInputSchemaEncodingContainer<T>(schema: mutableSchema)
  )
  return String(decoding: data, as: UTF8.self)
}
