import Foundation

struct GenerationDraft: Equatable {
  var configurationMode: ConfigurationMode = .simple
  var provider: ProviderID = .bailian
  var methodContent: String = PaperBananaSamples.sampleMethod
  var caption: String = "图 1：所提出的多智能体学术图示生成框架总览。"
  var infographicCategoryID: String = "method_framework"
  var outputFormat: OutputFormat = .png
  var imageSize: ImageSize = .oneK
  var mainModelName: String = ProviderCatalog.config(for: .bailian).mainModel
  var imageModelName: String = ProviderCatalog.config(for: .bailian).imageModel
  var referenceVisionModelName: String = ProviderCatalog.config(for: .bailian).visionModel
  var referenceImageMode: ReferenceImageMode = .visionModel
  var referenceImages: [PendingReferenceImage] = []
  var pipelineMode: PipelineMode = .plannerCritic
  var retrievalSetting: RetrievalSetting = .none
  var manualReferenceIds: [String] = []
  var aspectRatio: String = "16:9"
  var numCandidates: Int = 1
  var maxCriticRounds: Int = 1

  var selectedCategory: InfographicCategory {
    PaperBananaSamples.categories.first { $0.id == infographicCategoryID } ?? PaperBananaSamples.categories[0]
  }

  var taskName: TaskName {
    infographicCategoryID == "data_stat" ? .plot : .diagram
  }

  mutating func applyProviderDefaults(_ provider: ProviderID) {
    self.provider = provider
    let config = ProviderCatalog.config(for: provider)
    mainModelName = config.mainModel
    imageModelName = config.imageModel
    referenceVisionModelName = config.visionModel
    let supported = ProviderCatalog.supportedResolutions(provider: provider, imageModel: imageModelName)
    if !supported.contains(imageSize) {
      imageSize = supported.first ?? .oneK
    }
  }
}
