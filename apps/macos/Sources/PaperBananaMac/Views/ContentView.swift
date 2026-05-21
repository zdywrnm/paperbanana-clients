import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationSplitView {
      SidebarView(model: model)
    } content: {
      switch model.section {
      case .generate:
        ComposerView(model: model)
      case .records:
        RecordsListView(model: model)
      case .templates:
        TemplatesView(model: model)
      }
    } detail: {
      switch model.section {
      case .generate:
        GenerationInspectorView(model: model)
      case .records:
        JobDetailView(model: model, job: model.selectedRecord)
      case .templates:
        GenerationInspectorView(model: model)
      }
    }
    .navigationTitle("PaperBanana")
    .toolbar {
      ToolbarItemGroup {
        Button {
          Task { await model.refreshActiveSection() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }

        Button {
          Task { await model.submitJob() }
        } label: {
          Label("Generate", systemImage: "wand.and.stars")
        }
        .disabled(!model.canSubmit)
      }

      ToolbarItem(placement: .automatic) {
        if let user = model.currentUser {
          Menu {
            Button("Sign Out") {
              Task { await model.signOut() }
            }
          } label: {
            Label(user.email, systemImage: "person.crop.circle.fill")
          }
        } else {
          Button {
            model.isAuthSheetPresented = true
          } label: {
            Label("Sign In", systemImage: "person.crop.circle")
          }
        }
      }
    }
    .sheet(isPresented: $model.isAuthSheetPresented) {
      AuthSheetView(model: model)
    }
    .alert("PaperBanana", isPresented: $model.isAlertPresented) {
      Button("OK") {}
    } message: {
      Text(model.alertMessage)
    }
  }
}
