import SwiftUI

struct GuideView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
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
      .paperCompactTabBarInset()
      .background(AppBackground())
      .navigationTitle("使用指南")
    }
  }

  private var hero: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label("使用教程", systemImage: "book")
          .font(.title3.bold())
        Text(PaperBananaGuide.intro)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var quickActions: some View {
    GlassPanel {
      HStack(spacing: 12) {
        Button {
          model.selectedTab = .generate
        } label: {
          Label("开始生成", systemImage: "wand.and.stars")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .paperGlassButton(prominent: true)

        Button {
          model.selectedTab = .settings
        } label: {
          Label("意见反馈", systemImage: "message")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .paperGlassButton()
      }
    }
  }

  private var faqSection: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label("提示与常见问题", systemImage: "questionmark.circle")
          .font(.headline)
        ForEach(PaperBananaGuide.faq, id: \.self) { item in
          Label(item, systemImage: "checkmark.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var resourcesSection: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label("相关资源", systemImage: "link")
          .font(.headline)
        ForEach(PaperBananaGuide.resources) { resource in
          Link(destination: resource.url) {
            HStack(spacing: 10) {
              Image(systemName: resource.systemImage)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                  .font(.callout.weight(.semibold))
                Text(resource.subtitle)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "arrow.up.right")
                .font(.caption)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

struct GuideStepSection: View {
  let title: String
  let systemImage: String
  let steps: [GuideStep]

  var body: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 12) {
        Label(title, systemImage: systemImage)
          .font(.headline)
        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
          HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
              .font(.caption.monospacedDigit().bold())
              .foregroundStyle(.white)
              .frame(width: 24, height: 24)
              .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 4) {
              Text(step.title)
                .font(.callout.bold())
              Text(step.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
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
      VStack(alignment: .leading, spacing: 10) {
        Label(title, systemImage: systemImage)
          .font(.headline)
        ForEach(terms) { term in
          VStack(alignment: .leading, spacing: 4) {
            Text(term.name)
              .font(.callout.weight(.semibold))
            Text(term.detail)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
  }
}
