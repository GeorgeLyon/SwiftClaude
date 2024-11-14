/// Tool inputs and tool input schemas can be arbitrary encodable types
/// This type allows us to store them type-erased while maintaining encodability
/// This is also useful for encoding enum-like things that don't need to be `switch`-ed over (like content blocks) without having to make them enums
/// This needs to be a concrete type (as opposed to `any Encodable`) because `CacheableComponentArray` requires its generic parameter conform to `Encodable` which the existential `any Encodable` does not.
/// `any Encodable` also breaks the automatic `Encodable` implementation.
struct AnyEncodable: Encodable, Sendable {
  init(_ value: any Encodable & Sendable) {
    self.value = value
  }
  func encode(to encoder: any Encoder) throws {
    try value.encode(to: encoder)
  }
  private let value: Encodable & Sendable
}
