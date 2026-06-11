import SwiftUI

struct RootView: View {
  @Bindable var model: AppModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    rootContent
    .sheet(item: $model.refineSourceImage) { image in
      RefineSheet(model: model, image: image)
    }
    .sheet(item: $model.exportedResultFile) { file in
      ShareSheet(items: [file.url])
        .presentationDetents([.medium, .large])
    }
    .alert("PaperBanana", isPresented: $model.isAlertPresented) {
      Button("好", role: .cancel) {}
    } message: {
      Text(model.alertMessage)
    }
  }

  @ViewBuilder
  private var rootContent: some View {
    if horizontalSizeClass == .regular {
      NavigationSplitView {
        List(selection: Binding<AppTab?>(
          get: { model.selectedTab },
          set: { if let tab = $0 { model.selectedTab = tab } }
        )) {
          ForEach(AppTab.allCases) { tab in
            Label(tab.title, systemImage: tab.symbol)
              .tag(tab)
          }
        }
        .navigationTitle("PaperBanana")
      } detail: {
        selectedContent
      }
    } else {
      TabView(selection: $model.selectedTab) {
        GenerateView(model: model)
          .tabItem { Label(AppTab.generate.title, systemImage: AppTab.generate.symbol) }
          .tag(AppTab.generate)

        RecordsView(model: model)
          .tabItem { Label(AppTab.records.title, systemImage: AppTab.records.symbol) }
          .tag(AppTab.records)

        GuideView(model: model)
          .tabItem { Label(AppTab.guide.title, systemImage: AppTab.guide.symbol) }
          .tag(AppTab.guide)

        TemplatesView(model: model)
          .tabItem { Label(AppTab.templates.title, systemImage: AppTab.templates.symbol) }
          .tag(AppTab.templates)

        SettingsView(model: model)
          .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
          .tag(AppTab.settings)
      }
      .toolbarBackground(.regularMaterial, for: .tabBar)
      .toolbarBackground(.visible, for: .tabBar)
    }
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch model.selectedTab {
    case .generate:
      GenerateView(model: model)
    case .records:
      RecordsView(model: model)
    case .guide:
      GuideView(model: model)
    case .templates:
      TemplatesView(model: model)
    case .settings:
      SettingsView(model: model)
    }
  }
}
