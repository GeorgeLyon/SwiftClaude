import SwiftUI
import Claude

public struct ClaudeProvider<Content: View>: View {
  
  let defaultModel: Claude.Model
  
  @ViewBuilder
  let content: (Claude) -> Content
  
  public var body: some View {
    switch authenticator.authenticationState {
    case .authenticated(let summary):
      NavigationStack {
        ClaudeProviderContentWrapper(
          authenticator: authenticator,
          defaultModel: defaultModel,
          content: content
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("SwiftClaude")
        .toolbar {
          ToolbarItem(placement: .destructiveAction) {
            Button {
              isClearAPIKeyAlertPresented = true
            } label: {
              Image(systemName: "key")
                .help("Clear Current API Key (\(summary))")
            }
          }
        }
      }
      .alert(isPresented: $isClearAPIKeyAlertPresented) {
        Alert(
          title: Text("Current API Key:\n\(summary)"),
          primaryButton: .default(Text("OK")),
          secondaryButton: .destructive(Text("Change")) {
            _ = try? authenticator.deleteApiKey()
          }
        )
      }
    case .unauthenticated:
      SetAPIKeyView(authenticator: authenticator)
        .padding()
    case .failed(let error):
      HStack {
        Text("Failed: \(error)")
        Button("Reset") {
          authenticator.refreshAuthenticationState()
        }
      }
    }
  }
  
  @State
  private var isClearAPIKeyAlertPresented = false
  
  @State
  private var authenticator = Claude.KeychainAuthenticator(
    namespace: "com.github.georgelyon.SwiftClaudeProjectTemplate",
    identifier: "claude-api-key"
  )
  
}

// MARK: - Implementation Details

private struct ClaudeProviderContentWrapper<Content: View>: View {
  
  init(
    authenticator: Claude.Authenticator,
    defaultModel: Claude.Model,
    content: @escaping (Claude) -> Content
  ) {
    self.content = content
    self.claude = Claude(
      authenticator: authenticator,
      defaultModel: defaultModel
    )
  }
  
  let content: (Claude) -> Content
  
  var body: some View {
    content(claude)
  }
  
  @State
  private var claude: Claude
}

private struct SetAPIKeyView: View {

  let authenticator: Claude.KeychainAuthenticator

  var body: some View {
    HStack {
      Button(
        action: { isSecure.toggle() },
        label: {
          Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
        }
      )
      .buttonStyle(BorderlessButtonStyle())
      PossiblySecureField(
        isSecure: isSecure,
        text: $apiKey,
        prompt: Text("API Key"),
        label: {
          Text("API Key")
        }
      )
      .onSubmit {
        try? authenticator.save(.init(apiKey))
        apiKey = ""
      }
      Button("Save") {
        try? authenticator.save(.init(apiKey))
        apiKey = ""
      }
    }
  }

  @State private var isSecure = true
  @State private var apiKey = ""

}

private struct PossiblySecureField<Label: View>: View {

  let isSecure: Bool

  @Binding var text: String

  let prompt: Text?

  @ViewBuilder let label: () -> Label

  var body: some View {
    if isSecure {
      SecureField(text: $text, prompt: prompt, label: label)
    } else {
      TextField(text: $text, prompt: prompt, label: label)
    }
  }
}

#Preview("PossiblySecureField(isSecure: true)") {
  @Previewable @State var text = "Secret"
  PossiblySecureField(
    isSecure: true,
    text: $text,
    prompt: Text("Prompt"),
    label: {
      Text("Label")
    }
  )
}

#Preview("PossilySecureField(isSecure: false)") {
  @Previewable @State var text = "Secret"
  PossiblySecureField(
    isSecure: false,
    text: $text,
    prompt: Text("Prompt"),
    label: {
      Text("Label")
    }
  )
}
