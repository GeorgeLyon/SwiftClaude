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
