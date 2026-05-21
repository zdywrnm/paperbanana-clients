import Foundation

enum WorkbenchSection: String, CaseIterable, Identifiable {
  case generate
  case records
  case templates

  var id: String { rawValue }

  var title: String {
    switch self {
    case .generate: "Generate"
    case .records: "Records"
    case .templates: "Templates"
    }
  }

  var systemImage: String {
    switch self {
    case .generate: "wand.and.stars"
    case .records: "clock.arrow.circlepath"
    case .templates: "doc.text.magnifyingglass"
    }
  }
}

enum ConfigurationMode: String, CaseIterable, Codable, Identifiable {
  case simple
  case advanced

  var id: String { rawValue }

  var title: String {
    switch self {
    case .simple: "普通模式"
    case .advanced: "专业模式"
    }
  }
}

struct InfographicCategory: Identifiable, Equatable {
  let id: String
  let label: String
  let detail: String
}

struct QuickStartExample: Identifiable, Equatable {
  let id: String
  let label: String
  let title: String
  let categoryID: String
  let caption: String
  let methodContent: String
  let hint: String
}

struct GenerationDraft: Equatable {
  var configurationMode: ConfigurationMode = .simple
  var provider: ProviderID = .bailian
  var methodContent: String = PaperBananaSamples.sampleMethod
  var caption: String = "图 1：所提出的多智能体学术图示生成框架总览。"
  var infographicCategoryID: String = "method_framework"
  var mainModelName: String = ProviderCatalog.config(for: .bailian).mainModel
  var imageModelName: String = ProviderCatalog.config(for: .bailian).imageModel
  var pipelineMode: String = "demo_planner_critic"
  var retrievalSetting: String = "none"
  var aspectRatio: String = "16:9"
  var numCandidates: Int = 1
  var maxCriticRounds: Int = 1
  var mock: Bool = false

  mutating func applyProviderDefaults(_ provider: ProviderID) {
    self.provider = provider
    let config = ProviderCatalog.config(for: provider)
    mainModelName = config.mainModel
    imageModelName = config.imageModel
  }
}

enum PaperBananaSamples {
  static let categories: [InfographicCategory] = [
    InfographicCategory(id: "method_framework", label: "方法框架图", detail: "突出模块、智能体、输入输出和整体系统结构。"),
    InfographicCategory(id: "workflow", label: "流程图", detail: "突出步骤顺序、决策节点、循环和执行路径。"),
    InfographicCategory(id: "system_architecture", label: "系统架构图", detail: "突出前后端、数据层、模型接口和服务调用关系。"),
    InfographicCategory(id: "mechanism", label: "机制示意图", detail: "突出核心原理、变量关系、因果链路和作用机制。"),
    InfographicCategory(id: "comparison", label: "对比图", detail: "突出不同方法、模块、实验设置或方案之间的差异。"),
    InfographicCategory(id: "timeline", label: "时间线/路线图", detail: "突出阶段、里程碑、演进过程和计划安排。"),
    InfographicCategory(id: "data_stat", label: "数据统计图", detail: "突出指标、趋势、分布、占比或实验结果。"),
    InfographicCategory(id: "concept_map", label: "概念关系图", detail: "突出关键词、层级、类别和概念之间的关系。")
  ]

  static let sampleMethod = "我们提出一个用于学术图示生成的检索增强多智能体框架。检索器会先从参考库中选择相关图例，规划器再把论文方法部分和目标图注转换为详细的视觉规格。风格智能体会补充适合论文发表的版式与配色建议，生成器据此渲染多张候选图，评审器则迭代检查语义一致性与可读性。"

  static let quickStartExamples: [QuickStartExample] = [
    QuickStartExample(
      id: "paper-framework",
      label: "论文框架",
      title: "检索增强多智能体框架",
      categoryID: "method_framework",
      caption: "图 1：检索增强多智能体学术图示生成框架总览。",
      methodContent: "我们提出一个用于学术图示生成的检索增强多智能体框架。用户输入论文方法内容和目标图注后，系统先由检索器从参考图例库中选取相似案例。规划器将论文文本拆解为模块、箭头关系和视觉层级，风格智能体补充论文发表所需的版式与配色建议。生成器依据视觉规格渲染多张候选图，评审器再检查语义一致性、结构完整性和可读性，并把修改意见反馈给生成器迭代优化。",
      hint: "把方法模块、输入输出、评价环节替换成自己的研究内容。"
    ),
    QuickStartExample(
      id: "workflow-service",
      label: "流程说明",
      title: "资料整理与报告生成流程",
      categoryID: "workflow",
      caption: "图 1：面向资料整理与报告生成的智能工作流。",
      methodContent: "我们构建一个面向资料整理与报告生成的智能工作流。用户先上传课程资料、访谈记录或业务文档，并填写希望得到的报告主题。系统对输入材料进行解析、去重和分段，随后根据主题检索相关片段并生成报告提纲。内容生成模块按照提纲撰写初稿，人工审核节点负责补充事实、修改表达和确认结构。确认后的内容会进入排版与导出模块，最终生成可分享的图文报告或演示材料。",
      hint: "把资料来源、处理步骤、审核节点、交付物换成自己的业务场景。"
    )
  ]
}
