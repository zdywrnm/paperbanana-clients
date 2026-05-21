import AppKit
import SwiftUI

struct GenerationInspectorView: View {
  @ObservedObject var model: AppModel

  private var providerBinding: Binding<ProviderID> {
    Binding(
      get: { model.draft.provider },
      set: { model.selectProvider($0) }
    )
  }

  private var apiKeyBinding: Binding<String> {
    Binding(
      get: { model.selectedAPIKey },
      set: { model.updateSelectedAPIKey($0) }
    )
  }

  var body: some View {
    Form {
      Section("Backend") {
        LabeledContent("Mode") {
          Text(model.health?.backendMode.rawValue.capitalized ?? "Unknown")
        }
        LabeledContent("URL") {
          Text(model.apiBase)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        if !model.healthError.isEmpty {
          Text(model.healthError)
            .foregroundStyle(.red)
        }
      }

      Section("Model") {
        Picker("Mode", selection: $model.draft.configurationMode) {
          ForEach(ConfigurationMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Picker("Provider", selection: providerBinding) {
          ForEach(ProviderCatalog.order) { provider in
            Text(ProviderCatalog.config(for: provider).label).tag(provider)
          }
        }

        SecureField(model.selectedProviderConfig.keyPlaceholder, text: apiKeyBinding)
          .textFieldStyle(.roundedBorder)

        Button("Open API Key Page") {
          NSWorkspace.shared.open(model.selectedProviderConfig.guideURL)
        }
      }

      Section("Defaults") {
        LabeledContent("Main Model", value: model.selectedProviderConfig.mainModel)
        LabeledContent("Image Model", value: model.selectedProviderConfig.imageModel)
        LabeledContent("Pipeline", value: "规划器 + 评审器")
        LabeledContent("Aspect Ratio", value: "16:9")
      }

      if model.draft.configurationMode == .advanced {
        Section("Advanced") {
          Picker("Pipeline", selection: $model.draft.pipelineMode) {
            Text("规划器 + 评审器").tag("demo_planner_critic")
            Text("完整流程").tag("demo_full")
            Text("基础生成").tag("vanilla")
          }

          Picker("Retrieval", selection: $model.draft.retrievalSetting) {
            Text("不使用检索").tag("none")
            Text("自动检索").tag("auto")
            Text("随机参考").tag("random")
            Text("手动参考").tag("manual")
          }

          Picker("Aspect Ratio", selection: $model.draft.aspectRatio) {
            Text("16:9").tag("16:9")
            Text("21:9").tag("21:9")
            Text("3:2").tag("3:2")
            Text("1:1").tag("1:1")
          }

          Stepper("Candidates: \(model.draft.numCandidates)", value: $model.draft.numCandidates, in: 1...4)
          Stepper("Critic Rounds: \(model.draft.maxCriticRounds)", value: $model.draft.maxCriticRounds, in: 0...3)

          TextField("Main Model", text: $model.draft.mainModelName)
          TextField("Image Model", text: $model.draft.imageModelName)

          if model.health?.mockEnabled == true {
            Toggle("Mock Mode", isOn: $model.draft.mock)
          }
        }
      }

      Section {
        Button {
          Task { await model.submitJob() }
        } label: {
          if model.isSubmitting {
            ProgressView()
          } else {
            Label("Generate Candidate", systemImage: "wand.and.stars")
          }
        }
        .disabled(!model.canSubmit)

        if !model.submitError.isEmpty {
          Text(model.submitError)
            .foregroundStyle(.red)
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, 8)
  }
}
