extension JSON {

  public enum ValueKind: Sendable {
    case object
    case array
    case string
    case number
    case boolean
    case null
  }

  public struct ValueDecodingState: Sendable {

    public init() {

    }

    fileprivate enum Phase {
      case readingValue
      case readingStringFragments
      case readingNextArrayElement
      case readingNextObjectProperty
    }
    fileprivate var phase: Phase = .readingValue

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
    try readValue(&state).decodingResult()
  }

  public mutating func peekValueKind() throws -> JSON.DecodingResult<JSON.ValueKind> {
    try _peekValueKind().decodingResult()
  }

  mutating func readValue(
    _ state: inout JSON.ValueDecodingState
  ) -> ReadResult<Void> {
    while true {
      switch state.phase {
      case .readingValue:
        readWhitespace()

        let start = createCheckpoint()
        switch _peekValueKind() {
        case .incomplete:
          return .incomplete
        case .notMatched(let error):
          return .notMatched(error)
        case .matched(let kind):
          switch kind {
          case .null:
            switch readNull() {
            case .matched:
              break
            case .notMatched(let error):
              return .notMatched(error)
            case .incomplete:
              restore(start)
              return .incomplete
            }
          case .boolean:
            switch readBoolean() {
            case .matched:
              break
            case .notMatched(let error):
              return .notMatched(error)
            case .incomplete:
              restore(start)
              return .incomplete
            }
          case .number:
            switch readNumber() {
            case .matched:
              break
            case .notMatched(let error):
              return .notMatched(error)
            case .incomplete:
              restore(start)
              return .incomplete
            }
          case .string:
            switch readStringStart() {
            case .incomplete:
              restore(start)
              return .incomplete
            case .notMatched(let error):
              return .notMatched(error)
            case .matched:
              state.phase = .readingStringFragments
              continue
            }
          case .array:
            switch readArrayUpToFirstElement() {
            case .incomplete:
              restore(start)
              return .incomplete
            case .notMatched(let error):
              return .notMatched(error)
            case .matched(.elementStart):
              state.nesting.append(.array)
              state.phase = .readingValue
              continue
            case .matched(.end):
              break
            }
          case .object:
            switch readObjectUpToFirstPropertyValue() {
            case .incomplete:
              restore(start)
              return .incomplete
            case .notMatched(let error):
              return .notMatched(error)
            case .matched(.propertyValueStart):
              state.nesting.append(.object)
              state.phase = .readingValue
              continue
            case .matched(.end):
              break
            }
          }
        }

      case .readingStringFragments:
        switch readRawStringFragments(onFragment: { _ in }) {
        case .incomplete:
          return .incomplete
        case .notMatched(let error):
          return .notMatched(error)
        case .matched:
          break
        }

      case .readingNextArrayElement:
        switch readArrayUpToNextElement() {
        case .incomplete:
          return .incomplete
        case .notMatched(let error):
          return .notMatched(error)
        case .matched(.elementStart):
          state.phase = .readingValue
          continue
        case .matched(.end):
          let nesting = state.nesting.popLast()
          assert(nesting == .array)
          break
        }

      case .readingNextObjectProperty:
        switch readObjectUpToNextPropertyValue() {
        case .incomplete:
          return .incomplete
        case .notMatched(let error):
          return .notMatched(error)
        case .matched(.propertyValueStart):
          state.phase = .readingValue
          continue
        case .matched(.end):
          let nesting = state.nesting.popLast()
          assert(nesting == .object)
          break
        }
      }

      switch state.nesting.last {
      case .none:
        return .matched(())
      case .array:
        state.phase = .readingNextArrayElement
      case .object:
        state.phase = .readingNextObjectProperty
      }
    }
  }

  mutating func _peekValueKind() -> ReadResult<JSON.ValueKind> {
    readWhitespace()

    return peekCharacter { character in
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
    }
  }

}
