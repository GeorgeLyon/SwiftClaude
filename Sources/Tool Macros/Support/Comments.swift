import SwiftSyntax
import SwiftSyntaxBuilder

extension SyntaxProtocol where Self == LabeledExprSyntax {

  static func descriptionArgument(_ description: String?) -> Self {
    /// description: ...
    if let description {
      LabeledExprSyntax(
        label: "description",
        colon: .colonToken(),
        expression: StringLiteralExprSyntax(
          openDelimiter: .rawStringPoundDelimiter("#"),
          openingQuote: .multilineStringQuoteToken(),
          content: description,
          closingQuote: .multilineStringQuoteToken(),
          closeDelimiter: .rawStringPoundDelimiter("#")
        ),
        trailingComma: .commaToken(trailingTrivia: .newline)
      )
    } else {
      LabeledExprSyntax(
        label: "description",
        colon: .colonToken(),
        expression: NilLiteralExprSyntax(),
        trailingComma: .commaToken(trailingTrivia: .newline)
      )
    }
  }

}

extension SyntaxProtocol {

  var descriptionArgument: LabeledExprSyntax {
    return .descriptionArgument(comment)
  }

  var comment: String? {
    let comment =
      leadingTrivia
      .compactMap { trivia in
        switch trivia {
        case .docLineComment(let comment):
          return comment.trimmingPrefix("///")
        case .docBlockComment(let comment):
          var body = comment.trimmingPrefix("/**")
          guard body.hasSuffix("*/") else {
            assertionFailure()
            return body
          }
          body.removeLast("*/".count)
          return body
        case .lineComment(let comment):
          return comment.trimmingPrefix("//")
        case .blockComment(let comment):
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
