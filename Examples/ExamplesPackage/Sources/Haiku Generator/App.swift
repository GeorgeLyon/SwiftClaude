import SwiftUI

public protocol HaikuGeneratorApp: SwiftUI.App {

}

extension HaikuGeneratorApp {
  public var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .defaultSize(width: 300, height: 450)
  }
}
