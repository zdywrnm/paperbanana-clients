import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Form {
      Section("Sealos 后端") {
        TextField("网关地址", text: $model.apiBase)
          .textFieldStyle(.roundedBorder)
        Text("默认：\(AppDefaults.sealosAPIBase)")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Button("检查连接") {
            Task { await model.refreshHealth() }
          }
          Button("恢复 Sealos 默认地址") {
            model.resetBackendBase()
            Task { await model.refreshHealth() }
          }
        }

        if let health = model.health {
          LabeledContent("运行时", value: health.runtime)
          LabeledContent("模式", value: health.backendMode.rawValue)
          LabeledContent("详情", value: health.detail)
        }

        if !model.healthError.isEmpty {
          Text(model.healthError)
            .foregroundStyle(.red)
        }
      }

      Section("安全") {
        Text("模型 API Key 会按平台存入 macOS Keychain，只会在创建生成任务时发送给 Sealos 后端。")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
    .scrollContentBackground(.hidden)
    .background(PaperWorkspaceBackground().ignoresSafeArea())
  }
}
