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
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Generate Candidate Figures")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Paste the methodology text and target caption, then submit a generation job to the Sealos PaperBanana backend.")
        .foregroundStyle(.secondary)
    }
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
      Picker("Infographic Category", selection: $model.draft.infographicCategoryID) {
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
          Text("Methodology")
            .font(.headline)
          TextEditor(text: $model.draft.methodContent)
            .font(.body)
            .frame(minHeight: 260)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Figure Caption")
            .font(.headline)
          TextEditor(text: $model.draft.caption)
            .font(.body)
            .frame(minHeight: 260)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }
}
