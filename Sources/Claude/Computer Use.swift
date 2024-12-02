public import ClaudeClient

// MARK: - Computer Tool

extension Claude.Beta {

  public protocol ComputerTool: Claude.Tool
  where
    Input == Claude.Beta.ComputerToolInput
  {

    associatedtype Input = Claude.Beta.ComputerTool

    var displaySize: Claude.Image.Size { get }
    var displayNumber: Int? { get }
  }

}

extension Claude.Beta.ComputerTool {

  public var definition: Claude.ToolDefinition<Self> {
    .computer(displaySize: displaySize, displayNumber: displayNumber)
  }

  public static func decodeInput(
    for tool: Self,
    from payload: Claude.ToolInputDecoder<Self>.Payload,
    using decoder: Claude.ToolInputDecoder<Self>,
    isolation: isolated Actor
  ) async throws -> Input {
    let payload = try await decoder.decodeInput(
      of: Claude.Beta.ComputerToolInput.Payload.self,
      from: payload, isolation: isolation
    )
    return try Input(
      payload: payload,
      displaySize: try decoder.context.requestModel.vision.recommendedSize(
        forSourceImageOfSize: tool.displaySize,
        preprocessingMode: decoder.context.requestImagePreprocessingMode
      )
    )
  }

  public static func encodeInput(
    _ input: Input,
    to encoder: inout Claude.ToolInputEncoder<Self>
  ) {
    encoder.encode(input.payload)
  }

  public var displayNumber: Int? { nil }

}

// MARK: Input

extension Claude.Beta {

  public struct ComputerToolInput {

    public enum Action {
      case key(String)
      case type(String)
      case mouseMove(x: Double, y: Double)
      case leftClick
      case leftClickDrag(x: Double, y: Double)
      case rightClick
      case middleClick
      case doubleClick
      case screenshot
      case cursorPosition
    }
    public let action: Action

    fileprivate init(
      payload: Payload,
      displaySize: Claude.Image.Size
    ) throws {
      self.payload = payload
      switch payload.action {
      case .key:
        guard let text = payload.text else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .key(text)
      case .type:
        guard let text = payload.text else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .type(text)
      case .mouse_move:
        guard
          let coordinates = payload.coordinate,
          coordinates.count == 2
        else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .mouseMove(
          x: Double(coordinates[0]) / Double(displaySize.widthInPixels),
          y: Double(coordinates[1]) / Double(displaySize.heightInPixels)
        )
      case .left_click:
        action = .leftClick
      case .left_click_drag:
        guard
          let coordinates = payload.coordinate,
          coordinates.count == 2
        else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .leftClickDrag(
          x: Double(coordinates[0]) / Double(displaySize.widthInPixels),
          y: Double(coordinates[1]) / Double(displaySize.heightInPixels)
        )
      case .right_click:
        action = .rightClick
      case .middle_click:
        action = .middleClick
      case .double_click:
        action = .doubleClick
      case .screenshot:
        action = .screenshot
      case .cursor_position:
        action = .cursorPosition
      }
    }

    fileprivate struct Payload: Codable {
      enum Action: String, Codable {
        case key
        case type
        case mouse_move
        case left_click
        case left_click_drag
        case right_click
        case middle_click
        case double_click
        case screenshot
        case cursor_position
      }
      let action: Action
      let coordinate: [Int]?
      let text: String?
    }
    fileprivate let payload: Payload

    private struct InvalidPayload: Error {
    }
  }

}
