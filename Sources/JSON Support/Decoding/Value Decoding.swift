extension JSON {

  public struct ValueDecodingState {

    public init() {

    }

    fileprivate enum Phase {
      case decodingValue
      case decodingStringFragments
      case decodingNextArrayElement
      case decodingNextObjectProperty
    }
    fileprivate var phase: Phase = .decodingValue

    fileprivate enum Nesting {
      case array
      case object
    }
    fileprivate var nesting: [Nesting] = []

  }

}

extension JSON.DecodingStream {

  public mutating func decodeValue(
    _ state: inout JSON.ValueDecodingState
  ) throws -> JSON.DecodingResult<Void> {
    while true {
      switch state.phase {
      case .decodingValue:
        readWhitespace()

        let start = createCheckpoint()
        switch try peekValueKind() {
        case .needsMoreData:
          return .needsMoreData
        case .decoded(let kind):
          switch kind {
          case .null:
            switch try decodeNull() {
            case .decoded:
              break
            case .needsMoreData:
              restore(start)
              return .needsMoreData
            }
          case .boolean:
            switch try decodeBoolean() {
            case .decoded:
              break
            case .needsMoreData:
              restore(start)
              return .needsMoreData
            }
          case .number:
            switch try decodeNumber() {
            case .decoded:
              break
            case .needsMoreData:
              restore(start)
              return .needsMoreData
            }
          case .string:
            switch try decodeStringStart() {
            case .needsMoreData:
              restore(start)
              return .needsMoreData
            case .decoded:
              state.phase = .decodingStringFragments
              continue
            }
          case .array:
            switch try decodeArrayStart() {
            case .needsMoreData:
              restore(start)
              return .needsMoreData
            case .decodingElement:
              state.nesting.append(.array)
              state.phase = .decodingValue
              continue
            case .complete:
              break
            }
          case .object:
            switch try decodeObjectStart() {
            case .needsMoreData:
              restore(start)
              return .needsMoreData
            case .decodingPropertyValue:
              state.nesting.append(.object)
              state.phase = .decodingValue
              continue
            case .complete:
              break
            }
          }
        }

      case .decodingStringFragments:
        switch try readRawStringFragments(onFragment: { _ in }).decodingResult() {
        case .needsMoreData:
          return .needsMoreData
        case .decoded:
          break
        }

      case .decodingNextArrayElement:
        switch try decodeNextArrayElement() {
        case .needsMoreData:
          return .needsMoreData
        case .decodingElement:
          state.phase = .decodingValue
          continue
        case .complete:
          break
        }

      case .decodingNextObjectProperty:
        switch try decodeNextObjectProperty() {
        case .needsMoreData:
          return .needsMoreData
        case .decodingPropertyValue:
          state.phase = .decodingValue
          continue
        case .complete:
          break
        }
      }

      switch state.nesting.popLast() {
      case .none:
        return .decoded(())
      case .array:
        state.phase = .decodingNextArrayElement
      case .object:
        state.phase = .decodingNextObjectProperty
      }
    }
    fatalError()
  }

}

// MARK: - Implementation Details

extension JSON {

  fileprivate enum ValueKind {
    case object
    case array
    case string
    case number
    case boolean
    case null
  }

}

extension JSON.DecodingStream {

  fileprivate func peekValueKind() throws -> JSON.DecodingResult<JSON.ValueKind> {
    try peekCharacter { character in
      switch character {
      case "{":
        return .object
      case "[":
        return .array
      case "\"":
        return .string
      case "0"..."9", "-":
        return .number
      case "t", "f":
        return .boolean
      case "n":
        return .null
      default:
        return nil
      }
    }.decodingResult()
  }

}
