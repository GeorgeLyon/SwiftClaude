import SwiftSyntax
import SwiftSyntaxBuilder

extension DeclGroupSyntax {
  var accessModifiersForRequiredMembers: DeclModifierListSyntax {
    DeclModifierListSyntax {
      for modifier in modifiers {
        if ["private", "fileprivate"].contains(modifier.name.text) {
          DeclModifierSyntax(name: "fileprivate")
        } else if modifier.name.text == "public" {
          modifier
        }
      }
    }
  }
}

extension LabeledExprListSyntax {

  mutating func append(
    prependingCommaIfNeeded prependCommaIfNeeded: Bool,
    @LabeledExprListBuilder _ elements: () -> LabeledExprListSyntax
  ) {
    if prependCommaIfNeeded, let index = indices.last {
      self[index].trailingComma = .commaToken()
    }
    self.append(contentsOf: elements())
  }

}

// MARK: - Actually Used

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
