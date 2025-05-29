/*
extension JSON {

  public enum ObjectDecodingResult {
    case needsMoreData

    /// The read cursor has been advanced to the start of the property value
    case decodingPropertyValue(name: Substring)

    /// The object is complete
    case complete
  }

}

extension JSON.DecodingStream {

  public mutating func decodeObjectStart() throws -> JSON.ObjectDecodingResult {
    readWhitespace()

    let start = createCheckpoint()

    switch try read("{").decodingResult() {
    case .needsMoreData:
      return .needsMoreData
    case .decoded:
      readWhitespace()

      let isEmpty = readCharacter { character in
        switch character {
        case "}":
          return ()
        default:
          return nil
        }
      }

      switch isEmpty {
      case .matched:
        return .complete
      case .notMatched:
        let propertyResult = try decodePropertyName()
        switch propertyResult {
        case .needsMoreData:
          restore(start)
          return .needsMoreData
        case .decodingPropertyValue, .complete:
          return propertyResult
        }
      case .needsMoreData:
        restore(start)
        return .needsMoreData
      }
    }
  }

  public mutating func decodeNextObjectProperty() throws -> JSON.ObjectDecodingResult {
    readWhitespace()

    let beforeSeparator = createCheckpoint()

    let isComplete = try readCharacter { character in
      switch character {
      case "}":
        return true
      case ",":
        return false
      default:
        return nil
      }
    }.decodingResult()

    switch isComplete {
    case .needsMoreData:
      restore(beforeSeparator)
      return .needsMoreData
    case .decoded(let isComplete):
      if isComplete {
        return .complete
      } else {
        // Read whitespace after comma before decoding next property
        readWhitespace()
        let propertyResult = try decodePropertyName()
        switch propertyResult {
        case .needsMoreData:
          restore(beforeSeparator)
          return .needsMoreData
        case .decodingPropertyValue, .complete:
          return propertyResult
        }
      }
    }
  }

  private mutating func decodeNextPropertyName() -> ReadResult<Substring> {
    readWhitespace()

    var propertyFragments: [Substring] = []
    do {
      switch
      var state = try decodeStringStart().getValue()
      let result = try decodeStringFragments(state: &state) { fragment in
        propertyFragments.append(fragment)
      }
      if !state.isComplete {
        restore(propertyStart)
        return .needsMoreData
      }
    } catch {
      restore(propertyStart)
      throw error
    }

    switch try decodeString().decodingResult() {
    case .needsMoreData:
      restore(propertyStart)
      return .needsMoreData
    case .decoded(let propertyName):
      // Check for colon
      readWhitespace()
      switch try read(":").decodingResult() {
      case .needsMoreData:
        restore(propertyStart)
        return .needsMoreData
      case .decoded:
        readWhitespace()
        return .decodingPropertyValue(name: Substring(propertyName))
      }
    }
  }

}
*/
