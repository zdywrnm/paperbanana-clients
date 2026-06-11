import SwiftUI

struct ManualReferencePanel: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("手动参考")
          .font(.headline)
        Spacer()
        Button("刷新") {
          Task { await model.generation.loadReferenceLibrary() }
        }
      }
      if model.generation.referenceLibrary.isEmpty && !model.generation.referenceLibraryLoading {
        Button("加载参考库") {
          Task { await model.generation.loadReferenceLibrary() }
        }
      }
      if model.generation.referenceLibraryLoading {
        ProgressView()
      }
      if !model.generation.referenceLibraryError.isEmpty {
        Text(model.generation.referenceLibraryError)
          .font(.footnote)
          .foregroundStyle(.red)
      }
      ForEach(model.generation.referenceLibrary.prefix(12)) { item in
        Toggle(isOn: Binding(
          get: { model.generation.draft.manualReferenceIds.contains(item.id) },
          set: { _ in model.generation.toggleManualReference(item) }
        )) {
          VStack(alignment: .leading) {
            Text(item.title.isEmpty ? item.id : item.title)
            if !item.summary.isEmpty {
              Text(item.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
        }
      }
    }
  }
}
