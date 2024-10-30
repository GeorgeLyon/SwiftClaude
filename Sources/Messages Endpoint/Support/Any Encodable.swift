/// Tool inputs and tool input schemas can be arbitrary encodable types
/// This type allows us to store them type-erased while maintaining encodability
/// This is also useful for encoding enum-like things that don't need to be `switch`-ed over (like content blocks) without having to make them enums
struct AnyEncodable: Encodable {
  init(_ value: any Encodable) {
    self.value = value
  }
  func encode(to encoder: any Encoder) throws {
    try value.encode(to: encoder)
  }
  private let value: Encodable
}
