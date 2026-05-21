import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    Form {
      Section("Sealos Backend") {
        TextField("Gateway URL", text: $model.apiBase)
          .textFieldStyle(.roundedBorder)
        Text("Default: \(AppDefaults.sealosAPIBase)")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Button("Check Connection") {
            Task { await model.refreshHealth() }
          }
          Button("Reset to Sealos") {
            model.resetBackendBase()
            Task { await model.refreshHealth() }
          }
        }

        if let health = model.health {
          LabeledContent("Runtime", value: health.runtime)
          LabeledContent("Mode", value: health.backendMode.rawValue)
          LabeledContent("Detail", value: health.detail)
        }

        if !model.healthError.isEmpty {
          Text(model.healthError)
            .foregroundStyle(.red)
        }
      }

      Section("Security") {
        Text("Model API keys are stored in macOS Keychain per provider and are only sent with job creation requests.")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}
