import SwiftSyntax
import SwiftSyntaxBuilder

extension SyntaxProtocol {

  var comment: String? {
    let comment =
      leadingTrivia
      .compactMap { trivia in
        switch trivia {
        case let .docLineComment(comment):
          return comment.trimmingPrefix("///")
        case let .docBlockComment(comment):
          var body = comment.trimmingPrefix("/**")
          guard body.hasSuffix("*/") else {
            assertionFailure()
            return body
          }
          body.removeLast("*/".count)
          return body
        case let .lineComment(comment):
          return comment.trimmingPrefix("//")
        case let .blockComment(comment):
          var body = comment.trimmingPrefix("/*")
          guard body.hasSuffix("*/") else {
            assertionFailure()
            return body
          }
          body.removeLast("*/".count)
          return body
        default:
          return nil
        }
      }
      .map { (rawComment: Substring) -> Substring in
        let comment =
          if let lastNonWhitespaceCharacter =
            rawComment
            .lastIndex(where: { !$0.isWhitespace })
          {
            rawComment[...lastNonWhitespaceCharacter]
          } else {
            rawComment
          }

        return comment.trimmingPrefix { $0.isWhitespace }
      }
      .joined(separator: "\n")
    return comment.isEmpty ? nil : comment
  }

}
