func combineDescriptions(
  _ descriptions: String?...
) -> String? {
  let mapped = descriptions.compactMap(\.self)
  if mapped.isEmpty {
    return nil
  } else {
    return mapped.joined(separator: "\n")
  }
}
