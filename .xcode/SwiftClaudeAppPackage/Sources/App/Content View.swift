import ClaudeAPI
import ClaudeClient
import HaikuGenerator
import SwiftUI

struct ContentView: View {

  var body: some View {
    ClaudeProvider(
      defaultModel: .default
    ) { claude in
      TabView {
        Tab("Haiku Generator", systemImage: "sparkles.rectangle.stack") {
          HaikuGenerator(claude: claude)
        }
      }
    }
    .padding()

  }

  @State
  private var authenticator = Claude.KeychainAuthenticator(
    namespace: "com.codebygeorge.SwiftClaude.ComputerUse",
    identifier: "api-key"
  )
}

private struct APIKeyEntryView: View {

  let authenticator: Claude.KeychainAuthenticator

  var body: some View {
    HStack {
      TextField("API Key", text: $apiKey)
        .onSubmit {
          try? authenticator.save(Claude.APIKey(apiKey))
        }
      Button("Save") {
        try? authenticator.save(Claude.APIKey(apiKey))
      }
    }
  }

  @State
  private var apiKey: String = ""

}
