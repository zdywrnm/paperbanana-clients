import SwiftUI

struct ManualReferencePanel: View {
  @Bindable var model: AppModel

  @State private var currentPage = 0
  @State private var previewRequest: ManualReferencePreviewRequest?

  private static let pageSize = 10

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 300), spacing: Theme.Spacing.md)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      header
      if model.generation.referenceLibrary.isEmpty && !model.generation.referenceLibraryLoading {
        Button {
          reloadReferenceLibrary()
        } label: {
          Label("加载参考库", systemImage: "photo.stack")
            .frame(maxWidth: .infinity)
        }
        .paperGlassButton()
      }
      if model.generation.referenceLibraryLoading {
        ProgressView()
      }
      if !model.generation.referenceLibraryError.isEmpty {
        Text(model.generation.referenceLibraryError)
          .font(.footnote)
          .foregroundStyle(.red)
      }
      if !model.generation.referenceLibrary.isEmpty {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
          ForEach(visibleReferences) { item in
            let imageURL = model.resolvedImageURL(item.imageURL)
            ManualReferenceCard(
              item: item,
              imageURL: imageURL,
              isSelected: model.generation.draft.manualReferenceIds.contains(item.id),
              selectAction: {
                model.generation.toggleManualReference(item)
              },
              previewAction: {
                guard let imageURL else { return }
                previewRequest = ManualReferencePreviewRequest(item: item, url: imageURL)
              }
            )
          }
        }
        paginationControls
      }
    }
    .onChange(of: model.generation.referenceLibrary.count) { _, _ in
      clampCurrentPage()
    }
    .onChange(of: model.generation.draft.taskName) { _, _ in
      currentPage = 0
    }
    .fullScreenCover(item: $previewRequest) { request in
      ImageViewer(
        content: request.content,
        title: request.item.referenceDisplayTitle,
        shareURL: request.shareURL
      )
    }
  }

  private var header: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Text("手动参考")
        .font(.headline)
      if !model.generation.referenceLibrary.isEmpty {
        Text(visibleRangeText)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.Palette.paperGreenText)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Theme.Palette.paperGreen.opacity(0.08), in: Capsule())
          .accessibilityLabel("当前显示 \(visibleRangeText)")
      }
      Spacer()
      Text("\(model.generation.draft.manualReferenceIds.count)/10")
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityLabel("已选择 \(model.generation.draft.manualReferenceIds.count) 张，最多 10 张")
      Button {
        reloadReferenceLibrary()
      } label: {
        Label("刷新", systemImage: "arrow.clockwise")
          .font(.caption.weight(.semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Theme.Palette.paperGreenText)
    }
  }

  @ViewBuilder
  private var paginationControls: some View {
    if model.generation.referenceLibrary.count > Self.pageSize {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Theme.Spacing.md) {
          paginationButtons
        }
        VStack(spacing: Theme.Spacing.sm) {
          paginationButtons
        }
      }
      .padding(.top, Theme.Spacing.xs)
    }
  }

  @ViewBuilder
  private var paginationButtons: some View {
    Button {
      currentPage = max(0, currentPage - 1)
    } label: {
      Label("上一页", systemImage: "chevron.left")
    }
    .paperGlassButton()
    .disabled(currentPage == 0)

    Text("第 \(currentPage + 1)/\(totalPages) 页")
      .font(.caption.monospacedDigit().weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .accessibilityLabel("第 \(currentPage + 1) 页，共 \(totalPages) 页")

    Button {
      currentPage = min(totalPages - 1, currentPage + 1)
    } label: {
      Label("下一页", systemImage: "chevron.right")
    }
    .paperGlassButton()
    .disabled(currentPage >= totalPages - 1)
  }

  private var visibleReferences: [ReferenceLibraryItem] {
    let start = currentPage * Self.pageSize
    guard start < model.generation.referenceLibrary.count else { return [] }
    let end = min(start + Self.pageSize, model.generation.referenceLibrary.count)
    return Array(model.generation.referenceLibrary[start..<end])
  }

  private var totalPages: Int {
    max(1, Int(ceil(Double(model.generation.referenceLibrary.count) / Double(Self.pageSize))))
  }

  private var visibleRangeText: String {
    guard !model.generation.referenceLibrary.isEmpty else { return "0/0" }
    let start = currentPage * Self.pageSize + 1
    let end = min(start + Self.pageSize - 1, model.generation.referenceLibrary.count)
    return "\(start)-\(end)/\(model.generation.referenceLibrary.count)"
  }

  private func reloadReferenceLibrary() {
    currentPage = 0
    Task { await model.generation.loadReferenceLibrary() }
  }

  private func clampCurrentPage() {
    currentPage = min(max(currentPage, 0), totalPages - 1)
  }
}

private struct ManualReferenceCard: View {
  let item: ReferenceLibraryItem
  let imageURL: URL?
  let isSelected: Bool
  let selectAction: () -> Void
  let previewAction: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: Theme.Spacing.md) {
      previewButton

      Button(action: selectAction) {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
          copy
            .layoutPriority(1)
          Spacer(minLength: 0)
          selectionIcon
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(isSelected ? "取消选择" : "选择")参考图 \(item.referenceDisplayTitle)")
      .accessibilityHint("缩略图可单独放大查看")
      .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    .padding(Theme.Spacing.md)
    .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
    .background(cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        .strokeBorder(isSelected ? Theme.Palette.paperGreen : Theme.Palette.paperGreen.opacity(0.16), lineWidth: isSelected ? 1.6 : 1)
    }
  }

  private var previewButton: some View {
    Button(action: previewAction) {
      thumbnail(width: 120, height: 90, maxDimension: 148)
        .overlay(alignment: .bottomTrailing) {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(imageURL == nil ? 0.24 : 0.46), in: Circle())
            .padding(6)
            .accessibilityHidden(true)
        }
    }
    .buttonStyle(.plain)
    .disabled(imageURL == nil)
    .accessibilityLabel("放大查看参考图 \(item.referenceDisplayTitle)")
    .accessibilityHint("全屏查看，可捏合缩放")
  }

  private var selectionIcon: some View {
    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
      .font(.title3.weight(.semibold))
      .symbolRenderingMode(.palette)
      .foregroundStyle(isSelected ? .white : .secondary, isSelected ? Theme.Palette.paperGreen : .clear)
      .accessibilityHidden(true)
  }

  private var cardBackground: Color {
    isSelected ? Theme.Palette.paperGreen.opacity(0.11) : Theme.Palette.paperWell
  }

  private func thumbnail(width: CGFloat?, height: CGFloat, maxDimension: CGFloat) -> some View {
    Group {
      if imageURL != nil {
        DownsampledAsyncImage(url: imageURL, maxDimension: maxDimension) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
          case .failure:
            placeholder
          default:
            ProgressView()
              .controlSize(.small)
          }
        }
      } else {
        placeholder
      }
    }
    .frame(width: width, height: height)
    .frame(maxWidth: width == nil ? .infinity : nil)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .accessibilityHidden(true)
  }

  private var placeholder: some View {
    Image(systemName: PaperBananaSamples.categorySymbol(idOrLabel: item.taskName.rawValue))
      .font(.title3)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var copy: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(item.referenceDisplayTitle)
        .font(Font.caption.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .multilineTextAlignment(.leading)
      Text(item.chineseBriefIntro)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .truncationMode(.tail)
        .multilineTextAlignment(.leading)
      sourceBadge
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var sourceBadge: some View {
    Text(item.source)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(Theme.Palette.paperGreenText.opacity(0.82))
      .lineLimit(1)
      .minimumScaleFactor(0.78)
      .truncationMode(.middle)
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(Theme.Palette.paperGreen.opacity(0.08), in: Capsule())
  }
}

private struct ManualReferencePreviewRequest: Identifiable {
  let item: ReferenceLibraryItem
  let url: URL

  var id: String {
    "\(item.id)-\(url.absoluteString)"
  }

  var content: ImageViewer.Content {
    item.looksLikeSVG ? .svg(url) : .raster(url)
  }

  var shareURL: URL? {
    guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
      return nil
    }
    return url
  }
}

private extension ReferenceLibraryItem {
  var referenceDisplayTitle: String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedTitle.isEmpty ? "参考图 \(id)" : trimmedTitle
  }

  var chineseBriefIntro: String {
    let generated = "可参考「\(referenceDisplayTitle)」的\(taskName.referenceFocus)，用于控制生成图的风格与表达密度。"
    let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedSummary.containsCJK else { return generated }
    return "\(generated) \(trimmedSummary)"
  }

  var looksLikeSVG: Bool {
    let haystack = "\(imageURL) \(imageObjectKey)".lowercased()
    return haystack.contains(".svg") || haystack.contains("image/svg")
  }
}

private extension TaskName {
  var referenceFocus: String {
    switch self {
    case .diagram:
      return "结构层级、流程关系和视觉分组"
    case .plot:
      return "坐标组织、图例分组和数据标注"
    }
  }
}

private extension String {
  var containsCJK: Bool {
    unicodeScalars.contains { scalar in
      (0x4E00...0x9FFF).contains(Int(scalar.value))
    }
  }
}
