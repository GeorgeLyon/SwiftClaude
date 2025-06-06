public import SwiftDiagnostics
public import SwiftSyntax
public import SwiftSyntaxMacros

extension MacroExpansionContext {

  public func diagnose(_ error: DiagnosticError) {
    diagnose(error.diagnostic)
  }

}

public struct DiagnosticError: Error {

  public static func diagnose<T>(
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

  public init(
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
  public init(
    node: SyntaxProtocol,
    message: DiagnosticMessage
  ) {
    self.diagnostic = Diagnostic(node: node, message: message)
  }

  fileprivate let diagnostic: Diagnostic
}

public struct DiagnosticMessage: Identifiable, SwiftDiagnostics.DiagnosticMessage {

  public init(
    severity: DiagnosticSeverity,
    message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    self.severity = severity
    self.message = message
    self.id = ID(fileID: fileID, line: line)
  }

  public struct ID: Sendable, Hashable {
    let fileID: String
    let line: Int
  }
  public let id: ID

  public let severity: DiagnosticSeverity
  public let message: String
  public var diagnosticID: MessageID {
    MessageID(domain: #fileID, id: "\(id.fileID):\(id.line)")
  }
}
