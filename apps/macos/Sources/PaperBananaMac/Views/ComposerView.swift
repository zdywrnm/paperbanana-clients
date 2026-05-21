import SwiftUI

struct ComposerView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        quickExamples
        categoryPicker
        inputEditors
        JobResultPanel(model: model, job: model.currentJob)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(PaperWorkspaceBackground().ignoresSafeArea())
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 16) {
      AppIconMark(size: 64)
      VStack(alignment: .leading, spacing: 6) {
        Text("生成候选图")
          .font(.largeTitle)
          .fontWeight(.semibold)
        Text("粘贴论文方法内容和目标图注，PaperBanana 会通过 Sealos 后端生成学术图示候选结果。")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(18)
    .paperGlass(cornerRadius: 22)
  }

  private var quickExamples: some View {
    HStack(spacing: 8) {
      ForEach(PaperBananaSamples.quickStartExamples) { example in
        Button {
          model.applyExample(example)
        } label: {
          Label(example.label, systemImage: "doc.text")
        }
      }
    }
  }

  private var categoryPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker("信息图类别", selection: $model.draft.infographicCategoryID) {
        ForEach(PaperBananaSamples.categories) { category in
          Text(category.label).tag(category.id)
        }
      }
      .pickerStyle(.menu)

      Text(model.selectedCategory.detail)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var inputEditors: some View {
    Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
      GridRow {
        VStack(alignment: .leading, spacing: 8) {
          Text("论文方法内容")
            .font(.headline)
          TextEditor(text: $model.draft.methodContent)
            .font(.body)
            .frame(minHeight: 260)
            .scrollContentBackground(.hidden)
            .padding(8)
            .paperGlass(cornerRadius: 16)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("目标图注")
            .font(.headline)
          TextEditor(text: $model.draft.caption)
            .font(.body)
            .frame(minHeight: 260)
            .scrollContentBackground(.hidden)
            .padding(8)
            .paperGlass(cornerRadius: 16)
        }
      }
    }
  }
}
