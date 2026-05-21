import AppKit
import SwiftUI

@main
struct PaperBananaMacApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup("PaperBanana", id: "main") {
      ContentView(model: model)
        .frame(minWidth: 1180, minHeight: 760)
        .task {
          await model.bootstrap()
        }
    }
    .defaultSize(width: 1320, height: 860)
    .commands {
      CommandGroup(after: .newItem) {
        Button("Generate Candidate") {
          Task { await model.submitJob() }
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!model.canSubmit)

        Button("Refresh") {
          Task { await model.refreshActiveSection() }
        }
        .keyboardShortcut("r", modifiers: [.command])
      }

      CommandMenu("PaperBanana") {
        Button("Open Web Workbench") {
          NSWorkspace.shared.open(URL(string: "https://paperbanana.asia/")!)
        }

        Button("Open Paper") {
          NSWorkspace.shared.open(URL(string: "https://huggingface.co/papers/2601.23265")!)
        }
      }
    }

    Settings {
      SettingsView(model: model)
        .frame(width: 560)
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
