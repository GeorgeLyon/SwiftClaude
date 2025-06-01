import JSONSupport

extension JSON.DecodingResult {
  var needsMoreData: Bool {
    if case .needsMoreData = self {
      return true
    } else {
      return false
    }
  }
}
