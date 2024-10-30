import SwiftUI

public protocol ComputerUseApp: SwiftUI.App {

}

extension ComputerUseApp {
  public var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .defaultSize(width: 300, height: 450)
  }
}
