import SwiftUI

@main
struct PaperBananaApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
        .task {
          await model.bootstrap()
        }
    }
  }
}
