import Claude
import ClaudeClient
import ComputerUseDemo
import HaikuGenerator
import SwiftUI

/// Currently computer use doesn't work great, probably something to do with the image resizing logic

struct ContentView: View {

  var body: some View {
    ClaudeProvider(
      defaultModel: .claude35Sonnet20241022
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
