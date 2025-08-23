struct CodingKeyConversionStrategy: Sendable {
  static let convertToSnakeCase = Self(
    transform: String.convertToSnakeCase(_:)
  )
  static let none = Self(
    transform: { $0 }
  )

  func convert(_ string: String) -> String {
    transform(string)
  }

  private let transform: @Sendable (String) -> String
}
