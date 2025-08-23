import JSONSupport

extension JSON.DecodingResult {
  var isIncomplete: Bool {
    if case .incomplete = self {
      return true
    } else {
      return false
    }
  }
}
