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
          Task { await model.loadReferenceLibrary() }
        }
      }
      if model.referenceLibrary.isEmpty && !model.referenceLibraryLoading {
        Button("加载参考库") {
          Task { await model.loadReferenceLibrary() }
        }
      }
      if model.referenceLibraryLoading {
        ProgressView()
      }
      if !model.referenceLibraryError.isEmpty {
        Text(model.referenceLibraryError)
          .font(.footnote)
          .foregroundStyle(.red)
      }
      ForEach(model.referenceLibrary.prefix(12)) { item in
        Toggle(isOn: Binding(
          get: { model.draft.manualReferenceIds.contains(item.id) },
          set: { _ in model.toggleManualReference(item) }
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
