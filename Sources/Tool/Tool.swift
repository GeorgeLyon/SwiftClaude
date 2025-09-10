public import ClaudeCommon

#if canImport(UIKit)
public import UIKit
#endif

#if canImport(AppKit)
public import AppKit
#endif

// MARK: - Tool

public protocol Tool<Output> {

  associatedtype Definition: ToolDefinition<Input>
  var definition: Definition { get }

  associatedtype Input: Sendable
  associatedtype Output
  associatedtype Failure: Swift.Error

  func invoke(
    with input: Input,
    isolation: isolated Actor?
  ) async throws(Failure) -> Output

  func render(_ output: Output) -> ToolResultContent

}

extension Tool {

  public func invoke(
    with input: Input,
    isolation: isolated Actor? = #isolation
  ) async throws(Failure) -> Output {
    try await self.invoke(with: input, isolation: isolation)
  }

  public func render(_ output: Output) -> ToolResultContent {
    "\(output)"
  }

}

extension Tool where Output == String {

  public func render(_ output: Output) -> ToolResultContent {
    ToolResultContent(output)
  }

}

extension Tool where Output == ToolResultContent {

  public func render(_ output: Output) -> ToolResultContent {
    output
  }

}

// MARK: - Tool Definition

public protocol ToolDefinition<Input>: Encodable & Sendable {

  var name: String { get }

  associatedtype Input

  associatedtype InputSchema: ToolInput.Schema where InputSchema.Value == Input
  var inputSchema: InputSchema { get }

}

public struct ClientDefinedToolDefinition<InputSchema: ToolInput.Schema>: ToolDefinition {

  public init(
    name: String,
    description: String?,
    inputSchema: InputSchema
  ) {
    self.name = name
    self.description = description ?? ""
    self.inputSchema = inputSchema
  }

  public let name: String

  private let description: String

  public let inputSchema: InputSchema

}

extension ClientDefinedToolDefinition: Encodable {

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKey.self)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(description, forKey: .description)
    try inputSchema.encodeSchemaDefinition(
      to: ToolInput.SchemaEncoder(wrapped: container.superEncoder(forKey: .inputSchema))
    )
  }

  private enum CodingKey: Swift.CodingKey {
    case name, description, inputSchema
  }

}

// MARK: - Tool Result Content

public struct ToolResultContent: ExpressibleByStringInterpolation {

  public init(_ text: String) {
    self.components = [.text(text)]
  }

  public init(stringLiteral: String) {
    self.init(stringLiteral)
  }

  public init(stringInterpolation: StringInterpolation) {
    self.components = stringInterpolation.components
  }

  public struct StringInterpolation: StringInterpolationProtocol {

    public init(literalCapacity: Int, interpolationCount: Int) {
      components.reserveCapacity(literalCapacity + interpolationCount)
    }

    public mutating func appendLiteral(_ literal: String) {
      guard !literal.isEmpty else {
        return
      }
      if case .text(let prefix) = components.last {
        components.removeLast()
        components.append(.text(prefix + literal))
      } else {
        components.append(.text(literal))
      }
    }

    #if canImport(UIKit)
    public mutating func appendInterpolation(_ image: UIImage) {
      components.append(.image(Image(image)))
    }
    #endif

    #if canImport(AppKit)
    public mutating func appendInterpolation(_ image: NSImage) {
      components.append(.image(Image(image)))
    }
    #endif

    /// The following methods mirror those defined on `DefaultStringInterpolation`
    public mutating func appendInterpolation<T>(_ value: T)
    where T: CustomStringConvertible, T: TextOutputStreamable {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation<T>(_ value: T) where T: TextOutputStreamable {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation<T>(_ value: T) where T: CustomStringConvertible {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation<T>(_ value: T) {
      appendInterpolation(raw: value)
    }
    public mutating func appendInterpolation(_ value: any Any.Type) {
      appendInterpolation(raw: value)
    }

    /// `raw:`-prefixed methods to override other interpolations.
    public mutating func appendInterpolation<T>(raw value: T)
    where T: CustomStringConvertible, T: TextOutputStreamable {
      appendLiteral("\(value)")
    }
    public mutating func appendInterpolation<T>(raw value: T) where T: TextOutputStreamable {
      appendLiteral("\(value)")
    }
    public mutating func appendInterpolation<T>(raw value: T) where T: CustomStringConvertible {
      appendLiteral("\(value)")
    }
    public mutating func appendInterpolation<T>(raw value: T) {
      appendLiteral("\(value)")
    }
    public mutating func appendInterpolation(raw value: any Any.Type) {
      appendLiteral("\(value)")
    }

    fileprivate var components: [Component] = []

  }

  public init(components: [Component]) {
    self.components = components
  }

  public enum Component {
    case text(String)
    case image(Image)
  }
  public let components: [Component]

  public func render(
    vision: Vision,
    imagePreprocessingMode: Image.PreprocessingMode
  ) throws -> Rendered {
    try Rendered(
      components: components,
      vision: vision,
      imagePreprocessingMode: imagePreprocessingMode
    )
  }
  public struct Rendered: Codable, Sendable {

    public init(
      components: [ToolResultContent.Component],
      vision: Vision,
      imagePreprocessingMode: Image.PreprocessingMode
    ) throws {
      self.components = try components.map { component in
        switch component {
        case .text(let text):
          .text(.init(text: text))
        case .image(let image):
          try .image(
            image.block(
              vision: vision,
              preprocessingMode: imagePreprocessingMode
            )
          )
        }
      }
    }
    
    public init(from decoder: Decoder) throws {
      var container = try decoder.unkeyedContainer()
      var components: [Component] = []
      while !container.isAtEnd {
        let container = try container.superDecoder().singleValueContainer()
        switch try container.decode(AnyComponent.self).type {
        case .text:
          components.append(.text(try container.decode(TextBlock.self)))
        case .image:
          components.append(.image(try container.decode(ImageBlock.self)))
        }
      }
      self.components = components
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.unkeyedContainer()
      for component in components {
        switch component {
        case .text(let text):
          try container.encode(text)
        case .image(let image):
          try container.encode(image)
        }
      }
    }

    private enum Component {
      case text(TextBlock)
      case image(ImageBlock)
    }
    private let components: [Component]
    
    private enum ComponentType: String, Decodable {
      case text, image
    }
    private struct AnyComponent: Decodable {
      let type: ComponentType
    }
  }

}
