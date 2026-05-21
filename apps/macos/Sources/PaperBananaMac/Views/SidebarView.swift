import SwiftUI

struct SidebarView: View {
  @ObservedObject var model: AppModel

  private var selection: Binding<WorkbenchSection?> {
    Binding(
      get: { model.section },
      set: { value in
        if let value {
          model.section = value
        }
      }
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      List(selection: selection) {
        Section("Workspace") {
          ForEach(WorkbenchSection.allCases) { section in
            Label(section.title, systemImage: section.systemImage)
              .tag(section)
          }
        }
      }
      .listStyle(.sidebar)

      Divider()

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: model.health == nil ? "cloud.slash" : "cloud.fill")
            .foregroundStyle(model.health == nil ? Color.gray : Color.green)
          VStack(alignment: .leading, spacing: 2) {
            Text(model.health?.runtime.capitalized ?? "Backend")
              .font(.caption)
              .fontWeight(.semibold)
            Text(model.health?.detail ?? model.healthError.ifEmpty("Checking Sealos gateway"))
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }

        if let user = model.currentUser {
          Text(user.email)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else {
          Button("Sign In / Register") {
            model.isAuthSheetPresented = true
          }
          .buttonStyle(.borderless)
        }
      }
      .padding(12)
    }
  }
}

private extension String {
  func ifEmpty(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
