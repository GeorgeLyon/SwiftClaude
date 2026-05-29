import ClaudeClient

extension ClaudeClient.MessagesEndpoint.Request {

  struct CacheableComponentArray<Component>: ExpressibleByArrayLiteral {

    init(arrayLiteral elements: Element...) {
      self.init(elements: elements)
    }

    init(elements: [Element]) {
      self.elements = elements
    }

    enum Element {
      case component(Component)
      case cacheBreakpoint(CacheBreakpoint)

      var isCacheBreakpoint: Bool {
        if case .cacheBreakpoint = self {
          return true
        } else {
          return false
        }
      }
    }
    var elements: [Element]

    var containsCacheBreakpoints: Bool {
      elements.contains(where: \.isCacheBreakpoint)
    }

    typealias CacheBreakpoint = ClaudeClient.MessagesEndpoint.Request.CacheBreakpoint

  }

}

// MARK: - Sendability

extension ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray.Element: Sendable
where Component: Sendable {

}

extension ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray: Sendable
where Component: Sendable {

}

// MARK: - Encoding

extension ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray: Encodable
where Component: Encodable {

  func encode(to encoder: any Encoder) throws {
    let componentsWithCacheBreakpoints = try PeekSequence(elements)
      .compactMap { (next, peek) -> (Component, CacheBreakpoint?)? in
        switch next {
        case .component(let next):
          let cacheBreakpoint: CacheBreakpoint?
          switch peek {
          case .component, .none:
            cacheBreakpoint = nil
          case .cacheBreakpoint(let breakpoint):
            cacheBreakpoint = breakpoint
          }
          return (next, cacheBreakpoint)
        case .cacheBreakpoint:
          if case .cacheBreakpoint = peek {
            /// If there are two cache breakpoints in a row, there is no place to encode the behavior of the second breakpoint.
            assertionFailure()
            throw ConsecutiveCacheBreakpoints()
          }
          return nil
        }
      }

    var container = encoder.unkeyedContainer()
    for (component, breakpoint) in componentsWithCacheBreakpoints {
      let encoder = container.superEncoder()
      try component.encode(to: encoder)

      if let breakpoint {
        var container = encoder.container(keyedBy: CacheControlContainerCodingKey.self)
        switch breakpoint.cacheControl.kind {
        case .ephemeral(let control):
          try container.encode(control, forKey: .cacheControl)
        }
      }
    }
  }

  private enum CacheControlContainerCodingKey: String, CodingKey {
    case cacheControl
  }

  private struct ConsecutiveCacheBreakpoints: Error {}

}

// MARK: - Convenience

extension ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray {

  func map<T>(
    _ transform: (Component) throws -> T
  ) rethrows -> ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray<T> {
    ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray<T>(
      elements: try elements.map { element in
        switch element {
        case .component(let component):
          .component(try transform(component))
        case .cacheBreakpoint(let cacheBreakpoint):
          .cacheBreakpoint(cacheBreakpoint)
        }

      }
    )
  }
}
