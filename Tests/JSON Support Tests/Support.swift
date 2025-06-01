import JSONSupport

extension JSON.DecodingResult: Equatable where Value: Equatable {
  public static func == (lhs: JSON.DecodingResult<Value>, rhs: JSON.DecodingResult<Value>) -> Bool {
    switch (lhs, rhs) {
    case let (.decoded(lhs), .decoded(rhs)):
      return lhs == rhs
    case (.needsMoreData, .needsMoreData):
      return true
    default:
      return false
    }
  }
}
