import SwiftUI

struct TemplatesView: View {
  @Bindable var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 入场 stagger：已出现的卡片索引集合。
  @State private var appearedCards: Set<String> = []
  @State private var templateTitle = ""
  @State private var saveMessage = ""

  private let bottomTabClearance: CGFloat = 172

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          hero
          saveTemplatePanel
          savedTemplatesSection
          builtInTemplatesSection
        }
        .padding()
        .padding(.bottom, bottomTabClearance)
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  private var hero: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        SectionHeader(title: "模板库", systemImage: "book.closed")
        Text("把生成页当前配置保存成模板，也可以从常用科研图示案例开始，套用后会回到生成页继续编辑。")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var saveTemplatePanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        SectionHeader(title: "保存配置模板", systemImage: "tray.and.arrow.down")
        Text("记录当前生成页已经写好的配置：模式、模型、格式、清晰度、比例、类别、方法内容和目标图注。API Key 与本机参考图不会写入模板。")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        TextField("模板名称（可留空）", text: $templateTitle)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)
          .paperFieldWell()

        currentConfigurationPreview

        Button {
          let saved = model.saveCurrentTemplate(title: templateTitle)
          templateTitle = ""
          withAnimation(reduceMotion ? nil : Theme.Motion.stateChange) {
            saveMessage = "已保存「\(saved.displayTitle)」"
          }
        } label: {
          Label("保存当前配置", systemImage: "square.and.arrow.down")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .paperGlassButton(prominent: true)
        .accessibilityHint("把当前生成页草稿保存为本机模板")

        if !saveMessage.isEmpty {
          Label(saveMessage, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.Palette.paperGreenText)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
    }
  }

  private var currentConfigurationPreview: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
      Image(systemName: PaperBananaSamples.categorySymbol(idOrLabel: model.generation.draft.infographicCategoryID))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.Palette.paperGreenText)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text("当前配置")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(currentConfigurationSummary)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fieldWell()
  }

  private var currentConfigurationSummary: String {
    [
      model.generation.draft.selectedCategory.label,
      model.generation.draft.configurationMode.title,
      model.generation.selectedProviderConfig.label,
      model.generation.draft.outputFormat.title,
      model.generation.draft.imageSize.rawValue
    ].joined(separator: " · ")
  }

  private var savedTemplatesSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      SectionHeader(title: "我的模板", systemImage: "tray.full")

      if model.templates.templates.isEmpty {
        GlassPanel {
          Label("暂无自定义模板。先在生成页写好配置，再回到这里保存。", systemImage: "doc.badge.plus")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
          ForEach(model.templates.templates) { template in
            SavedTemplateCard(template: template) {
              model.applyTemplate(template)
            } onDelete: {
              withAnimation(reduceMotion ? nil : Theme.Motion.stateChange) {
                model.templates.delete(template)
              }
            }
          }
        }
      }
    }
  }

  private var builtInTemplatesSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      SectionHeader(title: "内置模板", systemImage: "sparkles.rectangle.stack")
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
        ForEach(Array(PaperBananaSamples.quickStartExamples.enumerated()), id: \.element.id) { index, example in
          TemplateCard(example: example) {
            model.applyExample(example)
          }
          .opacity(cardVisible(example.id) ? 1 : 0)
          .offset(y: cardVisible(example.id) ? 0 : 14)
          .onAppear { revealCard(example.id, index: index) }
        }
      }
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

private struct SavedTemplateCard: View {
  let template: SavedGenerationTemplate
  let onApply: () -> Void
  let onDelete: () -> Void

  private var configuration: SavedGenerationTemplateConfiguration {
    template.configuration
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      HStack(alignment: .top, spacing: Theme.Spacing.sm) {
        Text(configuration.categoryLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.Palette.paperGreenText)
          .padding(.horizontal, Theme.Spacing.sm)
          .padding(.vertical, 3)
          .background(Theme.Palette.paperGreenWell, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .lineLimit(1)
        Spacer(minLength: Theme.Spacing.xs)
        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("删除模板 \(template.displayTitle)")
      }

      Text(template.displayTitle)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)

      Text(configuration.methodContent)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text("配置摘要")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(summary)
          .font(.caption)
          .foregroundStyle(.primary)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .fieldWell()

      Button(action: onApply) {
        Label("套用模板", systemImage: "wand.and.stars")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .paperGlassButton(prominent: true)
      .accessibilityHint("把保存的配置填入生成表单并切换到生成页")
    }
    .padding(Theme.Spacing.md)
    .frame(maxWidth: .infinity, minHeight: 218, alignment: .topLeading)
    .background(Theme.Palette.paperPanel, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        .strokeBorder(Theme.Palette.paperBorder, lineWidth: 1)
    }
    .paperGlass(.interactive)
  }

  private var summary: String {
    [
      ProviderCatalog.config(for: configuration.provider).label,
      configuration.configurationMode.title,
      configuration.outputFormat.title,
      configuration.imageSize.rawValue,
      configuration.aspectRatio
    ].joined(separator: " · ")
  }
}

/// 模板卡：对齐小程序快速案例的紧凑纸卡，而不是营销式大卡。
struct TemplateCard: View {
  let example: QuickStartExample
  let onApply: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      HStack(alignment: .top, spacing: Theme.Spacing.sm) {
        Text(example.label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.Palette.warningText)
          .padding(.horizontal, Theme.Spacing.sm)
          .padding(.vertical, 3)
          .background(Theme.Palette.paperAmber.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .strokeBorder(Theme.Palette.paperAmber.opacity(0.55), lineWidth: 1)
          }
        Spacer(minLength: Theme.Spacing.xs)
        Image(systemName: PaperBananaSamples.categorySymbol(idOrLabel: example.categoryID))
          .font(.caption.weight(.semibold))
          .foregroundStyle(Theme.Palette.paperGreenText)
          .accessibilityHidden(true)
      }

      Text(example.title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)

      Text(example.hint)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)

      captionPreview

      Button {
        onApply()
      } label: {
        Label("套用模板", systemImage: "wand.and.stars")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .paperGlassButton(prominent: true)
      .accessibilityHint("把模板内容填入生成表单并切换到生成页")
    }
    .padding(Theme.Spacing.md)
    .frame(maxWidth: .infinity, minHeight: 238, alignment: .topLeading)
    .background(Theme.Palette.paperPanel, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        .strokeBorder(Theme.Palette.paperBorder, lineWidth: 1)
    }
    .paperGlass(.interactive)
  }

  private var captionPreview: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      Text("目标图注")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(example.caption)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fieldWell()
  }
}

#if DEBUG
#Preview("示例模板") {
  TemplatesView(model: AppModel())
}
#endif
