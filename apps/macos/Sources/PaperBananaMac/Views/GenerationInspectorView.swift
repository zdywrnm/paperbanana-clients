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

  private var mainModelBinding: Binding<String> {
    Binding(
      get: { model.draft.mainModelName },
      set: { model.draft.mainModelName = $0 }
    )
  }

  private var imageModelBinding: Binding<String> {
    Binding(
      get: { model.draft.imageModelName },
      set: { model.draft.imageModelName = $0 }
    )
  }

  var body: some View {
    Form {
      Section("后端") {
        LabeledContent("模式") {
          Text(model.health?.backendMode.rawValue.capitalized ?? "未知")
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

      Section("模型") {
        Picker("使用模式", selection: $model.draft.configurationMode) {
          ForEach(ConfigurationMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Picker("模型平台", selection: providerBinding) {
          ForEach(ProviderCatalog.order) { provider in
            Text(ProviderCatalog.config(for: provider).label).tag(provider)
          }
        }

        SecureField(model.selectedProviderConfig.keyPlaceholder, text: apiKeyBinding)
          .textFieldStyle(.roundedBorder)

        Button("打开 API Key 页面") {
          NSWorkspace.shared.open(model.selectedProviderConfig.guideURL)
        }
      }

      if model.draft.configurationMode == .simple {
        Section("普通模式默认配置") {
          LabeledContent("主模型", value: model.selectedProviderConfig.mainModelDisplayName)
          LabeledContent("图像模型", value: model.selectedProviderConfig.imageModelDisplayName)
          LabeledContent("生成流程", value: "规划器 + 评审器")
          LabeledContent("画面比例", value: "16:9")
        }
      }

      if model.draft.configurationMode == .advanced {
        Section("专业参数") {
          ModelPicker(
            title: "主模型",
            selection: mainModelBinding,
            groups: model.selectedProviderConfig.mainModelGroups
          )

          ModelPicker(
            title: "图像生成模型",
            selection: imageModelBinding,
            groups: model.selectedProviderConfig.imageModelGroups
          )

          Picker("生成流程", selection: $model.draft.pipelineMode) {
            Text("规划器 + 评审器").tag("demo_planner_critic")
            Text("完整流程").tag("demo_full")
            Text("基础生成").tag("vanilla")
          }

          Picker("检索设置", selection: $model.draft.retrievalSetting) {
            Text("不使用检索").tag("none")
            Text("自动检索").tag("auto")
            Text("随机参考").tag("random")
            Text("手动参考").tag("manual")
          }

          Picker("画面比例", selection: $model.draft.aspectRatio) {
            Text("16:9").tag("16:9")
            Text("21:9").tag("21:9")
            Text("3:2").tag("3:2")
            Text("1:1").tag("1:1")
          }

          Stepper("候选图数量：\(model.draft.numCandidates)", value: $model.draft.numCandidates, in: 1...4)
          Stepper("评审轮数：\(model.draft.maxCriticRounds)", value: $model.draft.maxCriticRounds, in: 0...3)

          if model.health?.mockEnabled == true {
            Toggle("模拟模式", isOn: $model.draft.mock)
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
            Label("生成候选图", systemImage: "wand.and.stars")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canSubmit)

        if !model.submitError.isEmpty {
          Text(model.submitError)
            .foregroundStyle(.red)
        }
      }
    }
    .formStyle(.grouped)
    .padding(.top, 8)
    .scrollContentBackground(.hidden)
    .background(PaperWorkspaceBackground().ignoresSafeArea())
  }
}

private struct ModelPicker: View {
  let title: String
  @Binding var selection: String
  let groups: [ModelOptionGroup]

  private var selectedOption: ModelOption? {
    groups.flatMap(\.options).first { $0.value == selection }
  }

  var body: some View {
    Picker(title, selection: $selection) {
      ForEach(groups) { group in
        Section(group.name) {
          ForEach(group.options) { option in
            Text(option.label).tag(option.value)
          }
        }
      }
    }
    .help(selectedOption?.value ?? selection)
  }
}
