import SwiftUI

struct StageTimelineView: View {
  @Bindable var model: AppModel
  let stages: [JobStage]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("生成演化")
        .font(.subheadline.bold())
      ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: stage.type == "critic" ? "text.bubble" : "photo")
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 2) {
                Text(stage.title.isEmpty ? stage.type : stage.title)
                  .font(.callout.bold())
                Text("候选 \(stage.candidateID + 1)\(stage.round > 0 ? " · 第 \(stage.round) 轮" : "")")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if stage.image?.url.isEmpty == false {
                Button {
                  Task { await model.exportStageImage(stage, index: index) }
                } label: {
                  Image(systemName: model.exportingStageImageID == stage.id ? "hourglass" : "square.and.arrow.down")
                }
                .disabled(model.exportingStageImageID == stage.id)
                .accessibilityLabel("保存或分享阶段图 \(index + 1)")
              }
            }
            if !stage.text.isEmpty {
              Text(stage.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            if let image = stage.image, let url = model.resolvedImageURL(image.url) {
              if image.mimeType.contains("svg") || image.filename.lowercased().hasSuffix(".svg") {
                SVGPreviewCard(url: url)
                  .frame(maxHeight: 180)
              } else {
                AsyncImage(url: url) { phase in
                  if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                  }
                }
                .frame(maxHeight: 180)
              }
            }
          }
        }
      }
    }
  }
}
