import SwiftDiagnostics
import SwiftSyntax

struct DiagnosticError: Error {
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
  init(node: SyntaxProtocol, message: DiagnosticMessage) {
    self.diagnostic = Diagnostic(node: node, message: message)
  }
  let diagnostic: Diagnostic
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

  let severity: DiagnosticSeverity
  let message: String

  struct ID: Hashable {
    let fileID: String
    let line: Int
  }
  let id: ID

  var diagnosticID: MessageID {
    MessageID(domain: #fileID, id: "\(id.fileID):\(id.line)")
  }
}
