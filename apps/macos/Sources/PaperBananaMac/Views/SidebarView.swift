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
      VStack(alignment: .leading, spacing: 10) {
        AppIconMark(size: 54)
        VStack(alignment: .leading, spacing: 3) {
          Text("PaperBanana")
            .font(.title3)
            .fontWeight(.semibold)
          Text("学术图示生成工作台")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)

      List(selection: selection) {
        Section("工作台") {
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
            Text(model.health?.detail ?? model.healthError.ifEmpty("正在连接 Sealos 网关"))
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
          Button("登录 / 注册") {
            model.isAuthSheetPresented = true
          }
          .buttonStyle(.borderless)
        }
      }
      .padding(12)
      .paperGlass(cornerRadius: 14)
      .padding(10)
    }
  }
}

private extension String {
  func ifEmpty(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
