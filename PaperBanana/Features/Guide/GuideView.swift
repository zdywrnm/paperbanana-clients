import SwiftUI

struct GuideView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          hero
          quickActions
          GuideStepSection(title: "三步上手", systemImage: "sparkles", steps: PaperBananaGuide.onboardingSteps)
          GuideStepSection(title: "多智能体流程", systemImage: "point.3.connected.trianglepath.dotted", steps: PaperBananaGuide.workflowSteps)
          GuideTermSection(title: "模型相关", systemImage: "cpu", terms: PaperBananaGuide.modelTerms)
          GuideTermSection(title: "生成参数", systemImage: "slider.horizontal.3", terms: PaperBananaGuide.parameterTerms)
          GuideTermSection(title: "检索与参考图", systemImage: "magnifyingglass", terms: PaperBananaGuide.referenceTerms)
          GuideTermSection(title: "结果区", systemImage: "photo.on.rectangle", terms: PaperBananaGuide.resultTerms)
          faqSection
          resourcesSection
        }
        .padding()
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("使用指南")
    }
  }

  private var hero: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Label("使用教程", systemImage: "book")
          .font(.title3.bold())
          .accessibilityAddTraits(.isHeader)
        Text(PaperBananaGuide.intro)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var quickActions: some View {
    GlassPanel {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Theme.Spacing.md) {
          quickActionButtons
        }
        VStack(spacing: Theme.Spacing.md) {
          quickActionButtons
        }
      }
    }
  }

  @ViewBuilder
  private var quickActionButtons: some View {
    Button {
      model.selectedTab = .generate
    } label: {
      Label("开始生成", systemImage: "wand.and.stars")
        .frame(maxWidth: .infinity)
    }
    .paperGlassButton(prominent: true)

    Button {
      model.selectedTab = .settings
    } label: {
      Label("意见反馈", systemImage: "message")
        .frame(maxWidth: .infinity)
    }
    .paperGlassButton()
  }

  private var faqSection: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Label("提示与常见问题", systemImage: "questionmark.circle")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        ForEach(PaperBananaGuide.faq, id: \.self) { item in
          GuideFAQRow(item: item)
        }
      }
    }
  }

  private var resourcesSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      Label("相关资源", systemImage: "link")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      ForEach(PaperBananaGuide.resources) { resource in
        GuideResourceRow(resource: resource)
      }
    }
  }
}

/// FAQ 行：有"，/；"分隔的条目折叠为 DisclosureGroup（首句做标题），其余保持单行提示。
struct GuideFAQRow: View {
  let item: String

  @State private var isExpanded: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// `initiallyExpanded` 仅供 #Preview / 视觉验证展开态使用，业务入口走默认收起。
  init(item: String, initiallyExpanded: Bool = false) {
    self.item = item
    _isExpanded = State(initialValue: initiallyExpanded)
  }

  /// 在第一个"，/；"处拆出标题与详情；拆不出则整条平铺。
  private var parts: (title: String, detail: String)? {
    guard let range = item.rangeOfCharacter(from: CharacterSet(charactersIn: "，；")) else { return nil }
    let title = String(item[..<range.lowerBound])
    let detail = String(item[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    guard !title.isEmpty, !detail.isEmpty else { return nil }
    return (title, detail)
  }

  var body: some View {
    if let parts {
      DisclosureGroup(isExpanded: animatedExpansion) {
        Text(parts.detail)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, Theme.Spacing.xs)
      } label: {
        Label(parts.title, systemImage: "questionmark.circle")
          .font(.footnote.weight(.semibold))
      }
      .tint(Theme.Palette.banana)
      .accessibilityHint(isExpanded ? "点按收起" : "点按展开详情")
    } else {
      Label(item, systemImage: "checkmark.circle")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var animatedExpansion: Binding<Bool> {
    Binding(
      get: { isExpanded },
      set: { newValue in
        withAnimation(reduceMotion ? nil : Theme.Motion.stateChange) {
          isExpanded = newValue
        }
      }
    )
  }
}

/// 外链行：独立可交互玻璃卡 + safari 外链指示。
struct GuideResourceRow: View {
  let resource: GuideResource

  var body: some View {
    Link(destination: resource.url) {
      HStack(spacing: Theme.Spacing.md) {
        Image(systemName: resource.systemImage)
          .font(.body.weight(.semibold))
          .foregroundStyle(Theme.Palette.banana)
          .frame(width: 28)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(resource.title)
            .font(.callout.weight(.semibold))
          Text(resource.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: Theme.Spacing.sm)
        Image(systemName: "safari")
          .font(.callout)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      .padding(Theme.Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .paperGlass(.interactive)
    .accessibilityHint("在浏览器中打开")
  }
}

struct GuideStepSection: View {
  let title: String
  let systemImage: String
  let steps: [GuideStep]

  var body: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Label(title, systemImage: systemImage)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
          HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("\(index + 1)")
              .font(.caption.monospacedDigit().bold())
              .foregroundStyle(.black.opacity(0.75))
              .frame(width: 24, height: 24)
              .background(Circle().fill(Theme.Palette.banana))
              .accessibilityLabel("第 \(index + 1) 步")
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
              Text(step.title)
                .font(.callout.bold())
              Text(step.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

struct GuideTermSection: View {
  let title: String
  let systemImage: String
  let terms: [GuideTerm]

  var body: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Label(title, systemImage: systemImage)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        ForEach(terms) { term in
          VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(term.name)
              .font(.callout.weight(.semibold))
            Text(term.detail)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Theme.Spacing.md)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

#if DEBUG
#Preview("使用指南") {
  GuideView(model: AppModel())
}

#Preview("FAQ 展开态") {
  GlassPanel {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      ForEach(Array(PaperBananaGuide.faq.enumerated()), id: \.offset) { index, item in
        GuideFAQRow(item: item, initiallyExpanded: index == 0)
      }
    }
  }
  .padding()
  .background(AppBackground())
}
#endif
