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
        Button("生成候选图") {
          Task { await model.submitJob() }
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!model.canSubmit)

        Button("刷新") {
          Task { await model.refreshActiveSection() }
        }
        .keyboardShortcut("r", modifiers: [.command])
      }

      CommandMenu("PaperBanana") {
        Button("打开网页版工作台") {
          NSWorkspace.shared.open(URL(string: "https://paperbanana.asia/")!)
        }

        Button("打开论文") {
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
