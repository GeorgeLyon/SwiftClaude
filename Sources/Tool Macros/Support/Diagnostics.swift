import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct DiagnosticError: Error {

  static func diagnose<T>(
    in context: some MacroExpansionContext,
    _ body: () throws -> T
  ) throws -> T {
    do {
      return try body()
    } catch let error as DiagnosticError {
      context.diagnose(error.diagnostic)
      throw error
    }
  }

  init(
    node: SyntaxProtocol,
    severity: DiagnosticSeverity,
    message: String
  ) {
    self.init(
      node: node,
      message: DiagnosticMessage(
        severity: severity,
        message: message
      )
    )
  }
  init(
    node: SyntaxProtocol,
    message: DiagnosticMessage
  ) {
    self.diagnostic = Diagnostic(node: node, message: message)
  }

  private let diagnostic: Diagnostic
}

struct DiagnosticMessage: Identifiable, SwiftDiagnostics.DiagnosticMessage {

  init(
    severity: DiagnosticSeverity,
    message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    self.severity = severity
    self.message = message
    self.id = ID(fileID: fileID, line: line)
  }

  struct ID: Hashable {
    let fileID: String
    let line: Int
  }
  let id: ID

  let severity: DiagnosticSeverity
  let message: String
  var diagnosticID: MessageID {
    MessageID(domain: #fileID, id: "\(id.fileID):\(id.line)")
  }
}
