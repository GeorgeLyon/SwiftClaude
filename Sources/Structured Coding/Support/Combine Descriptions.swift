/// Combines a use-site description with a type-level one, use-site first,
/// separated by a blank line. `nil`s are dropped.
func combineDescriptions(
  _ useSiteDescription: String?,
  _ typeDescription: String?
) -> String? {
  let descriptions = [useSiteDescription, typeDescription].compactMap(\.self)
  if descriptions.isEmpty {
    return nil
  }
  return descriptions.joined(separator: "\n\n")
}
