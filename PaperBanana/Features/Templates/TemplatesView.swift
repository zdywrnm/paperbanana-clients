import SwiftUI

struct TemplatesView: View {
  @Bindable var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 入场 stagger：已出现的卡片索引集合。
  @State private var appearedCards: Set<String> = []

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: Theme.Spacing.lg) {
          ForEach(Array(PaperBananaSamples.quickStartExamples.enumerated()), id: \.element.id) { index, example in
            TemplateCard(example: example) {
              model.applyExample(example)
            }
            .opacity(cardVisible(example.id) ? 1 : 0)
            .offset(y: cardVisible(example.id) ? 0 : 14)
            .onAppear { revealCard(example.id, index: index) }
          }
        }
        .padding()
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("示例模板")
    }
  }

  private func cardVisible(_ id: String) -> Bool {
    reduceMotion || appearedCards.contains(id)
  }

  /// 无论是否减弱动态都要记录"已出现"——运行中把减弱动态从开切到关时，
  /// 已出现的卡片不能因 appearedCards 缺位而翻回 opacity 0；仅入场动画按需跳过。
  private func revealCard(_ id: String, index: Int) {
    guard !appearedCards.contains(id) else { return }
    if reduceMotion {
      appearedCards.insert(id)
    } else {
      withAnimation(Theme.Motion.entrance.delay(Double(index) * 0.08)) {
        _ = appearedCards.insert(id)
      }
    }
  }
}

/// 模板卡：标题 + hint 摘要 + 图注预览区（样式化"假图"装饰）+ 应用按钮。
struct TemplateCard: View {
  let example: QuickStartExample
  let onApply: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
        Text(example.title)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: Theme.Spacing.sm)
        Text(example.label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.Palette.bananaText)
          .padding(.horizontal, Theme.Spacing.md)
          .padding(.vertical, Theme.Spacing.xs)
          .background(Theme.Palette.banana.opacity(0.14), in: .capsule)
      }

      captionPreview

      Text(example.hint)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Button {
        onApply()
      } label: {
        Label("应用此模板", systemImage: "wand.and.stars")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .paperGlassButton(prominent: true)
      .accessibilityHint("把模板内容填入生成表单并切换到生成页")
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperGlass(.panel)
  }

  /// 图注预览区：类别图标小型"假图" + 图注文字，模拟论文插图与图题的排版。
  private var captionPreview: some View {
    HStack(spacing: Theme.Spacing.md) {
      Image(systemName: PaperBananaSamples.categorySymbol(idOrLabel: example.categoryID))
        .font(.title2)
        .foregroundStyle(Theme.Palette.banana)
        .frame(width: 52, height: 52)
        .background(
          RoundedRectangle(cornerRadius: Theme.Radius.control)
            .fill(Theme.Palette.banana.opacity(0.10))
        )
        .overlay(
          RoundedRectangle(cornerRadius: Theme.Radius.control)
            .strokeBorder(Theme.Palette.banana.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .accessibilityHidden(true)
      Text(example.caption)
        .font(.footnote.italic())
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .fieldWell()
  }
}

#if DEBUG
#Preview("示例模板") {
  TemplatesView(model: AppModel())
}
#endif
