public struct TextBlock: Encodable, Sendable {

  public init(text: String) {
    self.text = text
  }

  private let type = "text"

  public let text: String

}
