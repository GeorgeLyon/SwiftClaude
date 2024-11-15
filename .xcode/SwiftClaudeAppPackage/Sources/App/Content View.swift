import Claude
import ClaudeClient
import SwiftUI

import HaikuGenerator
import ComputerUseDemo

/// Currently computer use doesn't work great, probably something to do with the image resizing logic

struct ContentView: View {
  
  var body: some View {
    VStack {
      switch authenticator.authenticationState {
      case .authenticated(let summary):
        HStack {
          Text(summary)
          Spacer()
          Button("Change API Key") {
            _ = try? authenticator.deleteApiKey()
          }
        }
        
        TabView {
          Tab("Haiku Generator", systemImage: "sparkles.rectangle.stack") {
            HaikuGenerator(authenticator: authenticator)
          }
          Tab("Computer Use Demo", systemImage: "desktopcomputer") {
            ComputerUseDemo(authenticator: authenticator)
          }
        }
        
      case .unauthenticated:
        APIKeyEntryView(authenticator: authenticator)
          .padding()
      case .failed(let error):
        Text("Failed: \(error)")
      }
      Spacer()
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
