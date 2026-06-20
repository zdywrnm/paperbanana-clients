import SwiftUI

struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    TabView(selection: $model.selectedTab) {
      Tab(AppTab.generate.title, systemImage: AppTab.generate.symbol, value: AppTab.generate) {
        GenerateView(model: model)
      }
      Tab(AppTab.records.title, systemImage: AppTab.records.symbol, value: AppTab.records) {
        RecordsView(model: model)
      }
      Tab(AppTab.guide.title, systemImage: AppTab.guide.symbol, value: AppTab.guide) {
        GuideView(model: model)
      }
      Tab(AppTab.templates.title, systemImage: AppTab.templates.symbol, value: AppTab.templates) {
        TemplatesView(model: model)
      }
      Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: AppTab.settings) {
        SettingsView(model: model)
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewBottomAccessory {
      if model.jobs.hasActiveJob {
        GenerationStatusAccessory(model: model)
      }
    }
    .sheet(item: $model.generation.refineSourceImage) { image in
      RefineSheet(model: model, image: image)
    }
    .sheet(item: $model.exports.exportedResultFile) { file in
      ShareSheet(items: [file.url])
        .presentationDetents([.medium, .large])
    }
    .alert("PaperBanana", isPresented: $model.isAlertPresented) {
      Button("好", role: .cancel) {}
    } message: {
      Text(model.alertMessage)
    }
  }
}
