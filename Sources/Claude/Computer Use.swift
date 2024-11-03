public import ClaudeClient

// MARK: - Computer Tool

extension Claude.Beta {

  public protocol ComputerTool: Claude.Tool
  where
    Input == Claude.Beta.ComputerToolInput,
    _ToolInvocationContextPrivateData == Claude.Beta.ComputerToolInput
      ._ToolInvocationContextPrivateData
  {

    associatedtype Input = Claude.Beta.ComputerTool
    associatedtype _ToolInvocationContextPrivateData = Input._ToolInvocationContextPrivateData

    var displaySize: Claude.Image.Size { get }
    var displayNumber: Int? { get }
  }

}

extension Claude.Beta.ComputerTool {

  public var definition: Claude.ToolDefinition<Self> {
    .computer(displaySize: displaySize, displayNumber: displayNumber)
  }

  public static func decodeInput(
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
      displaySize: decoder.context.privateData.adjustedDisplaySize
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

    public struct _ToolInvocationContextPrivateData {
      /// Size that allows us to account for image processing in display coordinate calculations
      init(adjustedDisplaySize: Claude.Image.Size) {
        self.adjustedDisplaySize = adjustedDisplaySize
      }
      fileprivate let adjustedDisplaySize: Claude.Image.Size
    }

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
