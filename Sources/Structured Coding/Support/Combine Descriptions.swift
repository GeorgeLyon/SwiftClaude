/// Combines a use-site description with a type-level one into the single
/// description a schema carries: the use-site description (from
/// `@StructuredProperty` / `@StructuredCase`, or prepended with
/// `prependDescription(_:)` directly) first, the type's own
/// `@StructuredCodable(description:)` second, separated by a blank line.
/// `nil`s are dropped, so a lone description is used as-is and combining two
/// `nil`s stays `nil`.
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
