import Foundation

enum ProviderCatalog {
  static let order: [ProviderID] = [.bailian, .openrouter, .gemini, .openai]

  static let providers: [ProviderID: ProviderConfig] = [
    .openrouter: ProviderConfig(
      id: .openrouter,
      label: "OpenRouter",
      keyName: "openrouter",
      keyPlaceholder: "sk-or-v1-...",
      mainModel: "openrouter/openai/gpt-5.5",
      imageModel: "openrouter/openai/gpt-5.4-image-2",
      visionModel: "openrouter/google/gemini-3.5-flash",
      mainModels: [
        option("openrouter/openai/gpt-5.5", "GPT-5.5", "OpenAI"),
        option("openrouter/openai/gpt-5.5-pro", "GPT-5.5 Pro", "OpenAI"),
        option("openrouter/openai/gpt-5.4", "GPT-5.4", "OpenAI"),
        option("openrouter/openai/gpt-5.4-pro", "GPT-5.4 Pro", "OpenAI"),
        option("openrouter/openai/gpt-5.4-mini", "GPT-5.4 Mini", "OpenAI"),
        option("openrouter/openai/gpt-5.4-nano", "GPT-5.4 Nano", "OpenAI"),
        option("openrouter/openai/gpt-chat-latest", "GPT Chat Latest", "OpenAI"),
        option("openrouter/openai/gpt-5.3-chat", "GPT-5.3 Chat", "OpenAI"),
        option("openrouter/~openai/gpt-latest", "GPT Latest", "OpenAI"),
        option("openrouter/~openai/gpt-mini-latest", "GPT Mini Latest", "OpenAI"),
        option("openrouter/anthropic/claude-opus-4.8", "Claude Opus 4.8", "Anthropic"),
        option("openrouter/anthropic/claude-opus-4.8-fast", "Claude Opus 4.8 Fast", "Anthropic"),
        option("openrouter/anthropic/claude-opus-4.7", "Claude Opus 4.7", "Anthropic"),
        option("openrouter/anthropic/claude-opus-4.7-fast", "Claude Opus 4.7 Fast", "Anthropic"),
        option("openrouter/~anthropic/claude-opus-latest", "Claude Opus Latest", "Anthropic"),
        option("openrouter/~anthropic/claude-sonnet-latest", "Claude Sonnet Latest", "Anthropic"),
        option("openrouter/google/gemini-3.1-pro-preview", "Gemini 3.1 Pro Preview", "Google"),
        option("openrouter/google/gemini-3.5-flash", "Gemini 3.5 Flash", "Google"),
        option("openrouter/google/gemini-3.1-flash-lite", "Gemini 3.1 Flash Lite", "Google"),
        option("openrouter/google/gemini-3.1-flash-lite-preview", "Gemini 3.1 Flash Lite Preview", "Google"),
        option("openrouter/~google/gemini-pro-latest", "Gemini Pro Latest", "Google"),
        option("openrouter/~google/gemini-flash-latest", "Gemini Flash Latest", "Google"),
        option("openrouter/qwen/qwen3.7-max", "Qwen3.7 Max", "Qwen"),
        option("openrouter/qwen/qwen3.6-plus", "Qwen3.6 Plus", "Qwen"),
        option("openrouter/qwen/qwen3.6-flash", "Qwen3.6 Flash", "Qwen"),
        option("openrouter/qwen/qwen3.6-max-preview", "Qwen3.6 Max Preview", "Qwen"),
        option("openrouter/qwen/qwen3.5-plus-20260420", "Qwen3.5 Plus 2026-04-20", "Qwen"),
        option("openrouter/deepseek/deepseek-v4-pro", "DeepSeek V4 Pro", "DeepSeek"),
        option("openrouter/deepseek/deepseek-v4-flash", "DeepSeek V4 Flash", "DeepSeek"),
        option("openrouter/x-ai/grok-4.3", "Grok 4.3", "xAI"),
        option("openrouter/x-ai/grok-4.20", "Grok 4.20", "xAI"),
        option("openrouter/x-ai/grok-4.20-multi-agent", "Grok 4.20 Multi-Agent", "xAI"),
        option("openrouter/x-ai/grok-build-0.1", "Grok Build 0.1", "xAI"),
        option("openrouter/moonshotai/kimi-k2.6", "Kimi K2.6", "Moonshot"),
        option("openrouter/z-ai/glm-5.1", "GLM 5.1", "Z.ai"),
        option("openrouter/minimax/minimax-m2.7", "MiniMax M2.7", "MiniMax"),
        option("openrouter/stepfun/step-3.7-flash", "Step 3.7 Flash", "StepFun")
      ],
      imageModels: [
        option("openrouter/openai/gpt-5.4-image-2", "GPT-5.4 Image 2", "OpenAI"),
        option("openrouter/openai/gpt-5-image", "GPT-5 Image", "OpenAI"),
        option("openrouter/openai/gpt-5-image-mini", "GPT-5 Image Mini", "OpenAI"),
        option("openrouter/google/gemini-3.1-flash-image-preview", "Nano Banana 2 / Gemini 3.1 Flash Image Preview", "Google"),
        option("openrouter/google/gemini-3-pro-image-preview", "Nano Banana Pro / Gemini 3 Pro Image Preview", "Google"),
        option("openrouter/google/gemini-2.5-flash-image", "Nano Banana / Gemini 2.5 Flash Image", "Google"),
        option("openrouter/x-ai/grok-imagine-image-quality", "Grok Imagine Image Quality", "xAI"),
        option("openrouter/recraft/recraft-v4.1-pro", "Recraft V4.1 Pro", "Recraft"),
        option("openrouter/recraft/recraft-v4.1", "Recraft V4.1", "Recraft"),
        option("openrouter/recraft/recraft-v4.1-pro-vector", "Recraft V4.1 Pro Vector", "Recraft"),
        option("openrouter/black-forest-labs/flux.2-pro", "FLUX.2 Pro", "Black Forest Labs"),
        option("openrouter/black-forest-labs/flux.2-flex", "FLUX.2 Flex", "Black Forest Labs"),
        option("openrouter/black-forest-labs/flux.2-max", "FLUX.2 Max", "Black Forest Labs"),
        option("openrouter/bytedance-seed/seedream-4.5", "Seedream 4.5", "ByteDance Seed"),
        option("openrouter/sourceful/riverflow-v2-pro", "Riverflow V2 Pro", "Sourceful"),
        option("openrouter/sourceful/riverflow-v2-fast", "Riverflow V2 Fast", "Sourceful")
      ],
      visionModels: [
        option("openrouter/google/gemini-3.5-flash", "Gemini 3.5 Flash", "Google"),
        option("openrouter/google/gemini-3.1-flash-lite", "Gemini 3.1 Flash Lite", "Google"),
        option("openrouter/openai/gpt-chat-latest", "GPT Chat Latest", "OpenAI"),
        option("openrouter/~openai/gpt-mini-latest", "GPT Mini Latest", "OpenAI"),
        option("openrouter/~google/gemini-flash-latest", "Gemini Flash Latest", "Google"),
        option("openrouter/qwen/qwen3.7-plus", "Qwen3.7 Plus", "Qwen"),
        option("openrouter/anthropic/claude-opus-4.8", "Claude Opus 4.8", "Anthropic"),
        option("openrouter/anthropic/claude-opus-4.8-fast", "Claude Opus 4.8 Fast", "Anthropic")
      ],
      guideURL: URL(string: "https://openrouter.ai/settings/keys")!,
      guideSteps: [
        "登录 OpenRouter，进入 Keys 页面。",
        "点击 Create Key，创建一个新的 API Key。",
        "复制 sk-or-v1- 开头的密钥，粘贴到上方输入框。"
      ]
    ),
    .gemini: ProviderConfig(
      id: .gemini,
      label: "Gemini",
      keyName: "gemini",
      keyPlaceholder: "AIza...",
      mainModel: "gemini-3.5-flash",
      imageModel: "gemini-3.1-flash-image",
      visionModel: "gemini-3.5-flash",
      mainModels: [
        option("gemini-3.5-flash", "Gemini 3.5 Flash", "Gemini 3.5"),
        option("gemini-3.1-pro-preview", "Gemini 3.1 Pro Preview", "Gemini 3.1"),
        option("gemini-3.1-pro", "Gemini 3.1 Pro", "Gemini 3.1"),
        option("gemini-3.1-flash-lite", "Gemini 3.1 Flash Lite", "Gemini 3.1"),
        option("gemini-3.1-flash-lite-preview", "Gemini 3.1 Flash Lite Preview", "Gemini 3.1"),
        option("gemini-3-flash", "Gemini 3 Flash", "Gemini 3"),
        option("gemini-3-flash-preview", "Gemini 3 Flash Preview", "Gemini 3"),
        option("gemini-3-pro-preview", "Gemini 3 Pro Preview", "Gemini 3"),
        option("gemini-2.5-pro", "Gemini 2.5 Pro", "Gemini 2.5"),
        option("gemini-2.5-flash", "Gemini 2.5 Flash", "Gemini 2.5"),
        option("gemini-2.5-flash-lite", "Gemini 2.5 Flash-Lite", "Gemini 2.5")
      ],
      imageModels: [
        option("gemini-3.1-flash-image", "Nano Banana 2 / Gemini 3.1 Flash Image", "Nano Banana"),
        option("gemini-3-pro-image", "Nano Banana Pro / Gemini 3 Pro Image", "Nano Banana"),
        option("gemini-2.5-flash-image", "Nano Banana / Gemini 2.5 Flash Image", "Nano Banana")
      ],
      visionModels: [
        option("gemini-3.5-flash", "Gemini 3.5 Flash", "Gemini 3.5"),
        option("gemini-3.1-pro", "Gemini 3.1 Pro", "Gemini 3.1"),
        option("gemini-3.1-pro-preview", "Gemini 3.1 Pro Preview", "Gemini 3.1"),
        option("gemini-2.5-pro", "Gemini 2.5 Pro", "Gemini 2.5"),
        option("gemini-2.5-flash", "Gemini 2.5 Flash", "Gemini 2.5"),
        option("gemini-2.5-flash-lite", "Gemini 2.5 Flash-Lite", "Gemini 2.5")
      ],
      guideURL: URL(string: "https://aistudio.google.com/app/apikey")!,
      guideSteps: [
        "登录 Google AI Studio，进入 API Keys 页面。",
        "点击 Create API key，选择或创建项目。",
        "复制生成的 AIza 开头密钥，粘贴到上方输入框。"
      ]
    ),
    .openai: ProviderConfig(
      id: .openai,
      label: "OpenAI",
      keyName: "openai",
      keyPlaceholder: "sk-...",
      mainModel: "gpt-5.5",
      imageModel: "gpt-image-2",
      visionModel: "gpt-4.1",
      mainModels: [
        option("gpt-5.5", "GPT-5.5", "GPT-5.5"),
        option("gpt-5.5-pro", "GPT-5.5 Pro", "GPT-5.5"),
        option("gpt-5.4", "GPT-5.4", "GPT-5.4"),
        option("gpt-5.4-pro", "GPT-5.4 Pro", "GPT-5.4"),
        option("gpt-5.4-mini", "GPT-5.4 Mini", "GPT-5.4"),
        option("gpt-5.4-nano", "GPT-5.4 Nano", "GPT-5.4"),
        option("gpt-5.2", "GPT-5.2", "GPT-5"),
        option("gpt-5.1", "GPT-5.1", "GPT-5"),
        option("gpt-5-mini", "GPT-5 Mini", "GPT-5"),
        option("gpt-4.1", "GPT-4.1", "GPT-4.1"),
        option("gpt-4.1-mini", "GPT-4.1 Mini", "GPT-4.1"),
        option("gpt-4o", "GPT-4o", "GPT-4o"),
        option("gpt-4o-mini", "GPT-4o Mini", "GPT-4o")
      ],
      imageModels: [
        option("gpt-image-2", "GPT Image 2", "GPT Image"),
        option("gpt-image-1.5", "GPT Image 1.5", "GPT Image"),
        option("gpt-image-1", "GPT Image 1", "GPT Image"),
        option("gpt-image-1-mini", "GPT Image 1 Mini", "GPT Image")
      ],
      visionModels: [
        option("gpt-4.1", "GPT-4.1", "GPT-4.1"),
        option("gpt-4.1-mini", "GPT-4.1 Mini", "GPT-4.1"),
        option("gpt-4o", "GPT-4o", "GPT-4o"),
        option("gpt-4o-mini", "GPT-4o Mini", "GPT-4o"),
        option("gpt-5.1", "GPT-5.1", "GPT-5"),
        option("gpt-5-mini", "GPT-5 Mini", "GPT-5")
      ],
      guideURL: URL(string: "https://platform.openai.com/api-keys")!,
      guideSteps: [
        "登录 OpenAI Platform，进入 API keys 页面。",
        "点击 Create new secret key，创建密钥。",
        "复制 sk- 开头的密钥，粘贴到上方输入框。"
      ]
    ),
    .bailian: ProviderConfig(
      id: .bailian,
      label: "阿里百炼",
      keyName: "bailian",
      keyPlaceholder: "sk-...",
      mainModel: "qwen3.7-max",
      imageModel: "wan2.7-image-pro",
      visionModel: "qwen3.7-plus",
      mainModels: [
        option("qwen3.7-max", "Qwen3.7 Max", "通义千问"),
        option("qwen3.7-plus", "Qwen3.7 Plus（可直读图）", "通义千问"),
        option("qwen3.6-flash", "Qwen3.6 Flash", "通义千问"),
        option("deepseek-v4-pro", "DeepSeek V4 Pro", "百炼第三方"),
        option("deepseek-v4-flash", "DeepSeek V4 Flash", "百炼第三方"),
        option("kimi-k2.6", "Kimi K2.6（可直读图）", "百炼第三方"),
        option("glm-5.1", "GLM 5.1", "百炼第三方"),
        option("MiniMax/MiniMax-M2.7", "MiniMax M2.7", "百炼第三方")
      ],
      imageModels: [
        option("wan2.7-image-pro", "Wan 2.7 Image Pro", "通义万相"),
        option("qwen-image-2.0-pro", "Qwen Image 2.0 Pro", "通义千问 Image")
      ],
      visionModels: [
        option("qwen3.7-plus", "Qwen3.7 Plus（图像理解）", "通义千问"),
        option("qwen3.5-omni-plus", "Qwen3.5 Omni Plus（全模态）", "通义千问"),
        option("kimi-k2.6", "Kimi K2.6（图像理解）", "百炼第三方")
      ],
      guideURL: URL(string: "https://help.aliyun.com/zh/model-studio/get-api-key")!,
      guideSteps: [
        "登录阿里云百炼控制台，确认已开通百炼模型服务。",
        "进入 API Key 页面，点击创建 API Key。",
        "建议选择默认业务空间和全部权限，复制 sk- 开头密钥。"
      ]
    )
  ]

  static func config(for id: ProviderID) -> ProviderConfig {
    providers[id] ?? providers[.bailian]!
  }

  static func mainModelCanReadImages(provider: ProviderID, model: String) -> Bool {
    let m = model.lowercased()
    switch provider {
    case .bailian:
      return m.range(of: #"qwen3\.7-plus|qwen3\.5-omni|omni|kimi-k2\.6|qwen-?vl|qwen3-?vl|-vl-|qvq"#, options: .regularExpression) != nil
    case .gemini, .openrouter:
      return true
    case .openai:
      return m.range(of: #"gpt-4|gpt-5|o4|gpt-4o|gpt-4\.1"#, options: .regularExpression) != nil
    }
  }

  static func supportedResolutions(provider: ProviderID, imageModel: String) -> [ImageSize] {
    switch provider {
    case .bailian, .gemini:
      return [.oneK, .twoK]
    case .openai, .openrouter:
      return [.oneK, .twoK, .fourK]
    }
  }

  static func option(_ value: String, _ label: String, _ group: String = "") -> ModelOption {
    ModelOption(value: value, label: label, group: group)
  }
}

enum PaperBananaSamples {
  static let sampleMethod = "我们提出一个用于学术图示生成的检索增强多智能体框架。检索器会先从参考库中选择相关图例，规划器再把论文方法部分和目标图注转换为详细的视觉规格。风格智能体会补充适合论文发表的版式与配色建议，生成器据此渲染多张候选图，评审器则迭代检查语义一致性与可读性。"

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

enum PaperBananaGuide {
  static let intro = "PaperBanana 是一个多智能体学术配图生成工具：把论文方法描述和目标图注交给它，多个 AI 角色协作产出框架图、流程图、架构图或统计图。模型 API Key 由你自带，只保存在本机 Keychain。"

  static let onboardingSteps: [GuideStep] = [
    GuideStep(
      id: "provider-key",
      title: "选接口、填 Key",
      detail: "选择 OpenRouter、Gemini、OpenAI 或阿里百炼之一，填入当前接口的 API Key。每个平台的申请指南在生成页 Key 输入框下方。"
    ),
    GuideStep(
      id: "paper-input",
      title: "填内容",
      detail: "选择信息图类别，粘贴论文方法部分和目标图注；如果有风格参考，可上传 PNG、JPG、WebP 或 SVG 参考图，最多 3 张。"
    ),
    GuideStep(
      id: "generate-export",
      title: "生成候选图",
      detail: "提交后等待任务轮询完成。结果图可单张分享，也可整单 ZIP 导出，包含结果、参考图、中间阶段和 metadata。"
    )
  ]

  static let workflowSteps: [GuideStep] = [
    GuideStep(id: "plan", title: "规划", detail: "主模型把方法内容和图注拆成目标图描述，明确模块、连接关系、布局和视觉层级。"),
    GuideStep(id: "render", title: "初次渲染", detail: "图像模型按规划生成第一版候选图。"),
    GuideStep(id: "critic", title: "图像评审", detail: "评审模型检查排版、文字和逻辑问题，并给出修改建议。"),
    GuideStep(id: "rerender", title: "重渲染", detail: "按评审意见继续改进，直到用完设置的评审轮数。"),
    GuideStep(id: "refine", title: "精修放大", detail: "可对任一结果图再次提交精修，并独立选择目标比例和清晰度。")
  ]

  static let modelTerms: [GuideTerm] = [
    GuideTerm(id: "provider", name: "模型接口（Provider）", detail: "选择哪家模型服务。切换接口会同步刷新主模型、图像模型、视觉模型和清晰度档位。"),
    GuideTerm(id: "main-model", name: "主模型", detail: "负责规划、文本评审和自动检索相关性排序。建议选择推理能力强的模型。"),
    GuideTerm(id: "image-model", name: "图像生成模型", detail: "负责真正出图，决定风格、质量上限和可用清晰度。"),
    GuideTerm(id: "vision-model", name: "参考图识别模型", detail: "当主模型不能直读参考图时，先把参考图读成文字描述，再交给生成链路。")
  ]

  static let parameterTerms: [GuideTerm] = [
    GuideTerm(id: "mode", name: "使用模式", detail: "普通模式使用平台预置配置；专业模式开放模型、流程、比例、候选数量和评审轮数。"),
    GuideTerm(id: "pipeline", name: "生成流程", detail: "规划器 + 评审器兼顾质量与速度；完整流程更细但更慢；基础生成跳过评审最快。"),
    GuideTerm(id: "candidates", name: "候选图数量", detail: "一次生成 1 到 3 张独立备选图。数量越多，耗时和模型成本越高。"),
    GuideTerm(id: "critic-rounds", name: "评审轮数", detail: "控制评审到重渲染的迭代次数，0 表示不评审。"),
    GuideTerm(id: "aspect-ratio", name: "画面比例", detail: "支持 16:9、21:9、3:2、1:1，按论文或幻灯版面选择。"),
    GuideTerm(id: "output-format", name: "导出格式", detail: "PNG 通用；SVG 可无损缩放，更适合后续排版精修。"),
    GuideTerm(id: "image-size", name: "输出清晰度", detail: "1K 最快；2K/4K 会按模型能力做更高清的结果。不可用档位会自动过滤。")
  ]

  static let referenceTerms: [GuideTerm] = [
    GuideTerm(id: "retrieval-none", name: "检索设置 · 不使用检索", detail: "不带任何范例，只按论文文字和图注生成。"),
    GuideTerm(id: "retrieval-auto", name: "检索设置 · 自动检索", detail: "从内置 PaperBanana 论文配图库中挑出相关范例作为风格与排版灵感。"),
    GuideTerm(id: "retrieval-random", name: "检索设置 · 随机参考", detail: "从参考库随机取图做风格灵感，不强调语义相关性。"),
    GuideTerm(id: "retrieval-manual", name: "检索设置 · 手动参考", detail: "你从参考库中手动选择最多 10 张范例。"),
    GuideTerm(id: "uploaded-reference", name: "上传参考图", detail: "一旦上传参考图，检索会自动关闭，以你的上传图作为唯一视觉风格来源。"),
    GuideTerm(id: "reference-mode", name: "参考图处理方式", detail: "主模型直读适合能读图的主模型；独立识别模型适合主模型不能读图的情况。")
  ]

  static let resultTerms: [GuideTerm] = [
    GuideTerm(id: "reference-echo", name: "参考回显", detail: "结果区会回显参考图，提醒它只作风格参考，不决定版式。"),
    GuideTerm(id: "candidate-image", name: "候选图", detail: "本次生成的结果图，可单张分享或整单打包。"),
    GuideTerm(id: "retrieved-reference", name: "检索参考", detail: "本次实际使用的参考范例标题列表。"),
    GuideTerm(id: "stage-timeline", name: "生成演化", detail: "展示规划、渲染、评审和中间图，便于理解模型为什么这样画。")
  ]

  static let faq: [String] = [
    "方法描述越具体，图中的模块、连接关系和层级越稳定。",
    "API Key 只保存在本机 Keychain；建议在各平台控制台定期轮换。",
    "出图不理想时，可以加评审轮数、换更强模型，或上传风格接近的参考图。",
    "某个清晰度选不到时，说明当前图像模型不支持该档位。",
    "任务记录页可回看历史任务、结果图、中间阶段和失败原因。"
  ]

  static let resources: [GuideResource] = [
    GuideResource(
      id: "website",
      title: "PaperBanana 网站",
      subtitle: "打开线上 Web 工作台",
      systemImage: "safari",
      url: URL(string: "https://www.paperbanana.asia/")!
    ),
    GuideResource(
      id: "paper",
      title: "论文",
      subtitle: "Hugging Face Papers",
      systemImage: "doc.text",
      url: URL(string: "https://huggingface.co/papers/2601.23265")!
    ),
    GuideResource(
      id: "github",
      title: "GitHub",
      subtitle: "PaperBanana 多端 monorepo",
      systemImage: "chevron.left.forwardslash.chevron.right",
      url: URL(string: "https://github.com/zdywrnm/PaperBanana-clients")!
    ),
    GuideResource(
      id: "android",
      title: "Android 版",
      subtitle: "GitHub Releases 预览包",
      systemImage: "smartphone",
      url: URL(string: "https://github.com/zdywrnm/PaperBanana-clients/releases/tag/android-preview-0.1.3")!
    ),
    GuideResource(
      id: "macos",
      title: "Mac 版",
      subtitle: "GitHub Releases 安装包",
      systemImage: "macbook",
      url: URL(string: "https://github.com/zdywrnm/PaperBanana-clients/releases/tag/macos-v0.1.0")!
    ),
    GuideResource(
      id: "miniprogram",
      title: "微信小程序",
      subtitle: "查看小程序源码目录",
      systemImage: "message",
      url: URL(string: "https://github.com/zdywrnm/PaperBanana-clients/tree/main/apps/miniprogram")!
    )
  ]
}
