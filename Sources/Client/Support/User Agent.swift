import Foundation

var userAgent: String {
  "\(userAgentApp) SwiftClaude/0.0.0 (\(userAgentPlatform))"
}

private var userAgentApp: String {
  #if canImport(Darwin)
    guard
      let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
    else {
      return "UnknownApp/UnknownVersion"
    }
    guard
      let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    else {
      return "\(appName)/UnknownVersion"
    }
    return "\(appName)/\(appVersion)"
  #else
    return "UnknownApp/UnknownVersion"
  #endif
}

private var userAgentPlatform: String {
  "\(ProcessInfo.processInfo.operatingSystemVersionString)"
}
