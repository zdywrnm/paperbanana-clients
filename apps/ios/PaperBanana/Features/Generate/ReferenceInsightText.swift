import Foundation

enum ReferenceInsightText {
  static func briefIntro(for item: ReferenceLibraryItem) -> String {
    if let curated = curatedDiagramBriefs[item.id] {
      return curated
    }

    switch item.taskName {
    case .diagram:
      return diagramBrief(title: item.title, summary: item.summary)
    case .plot:
      return plotBrief(title: item.title, summary: item.summary)
    }
  }
}

private extension ReferenceInsightText {
  static let curatedDiagramBriefs: [String: String] = [
    "6a26bcf2f0d6ef02acf1d988": "并行注意力对比：分块状态、通信路径和多种并行方案放在同图中比较。",
    "6a26bcf2f0d6ef02acf1d987": "强化学习探索流程：左侧讲互信息目标，右侧展示观测到嵌入的网络结构。",
    "6a26bcf2f0d6ef02acf1d986": "推荐系统框架：从多模态标签提取到用户/物品逻辑推理，多分支关系清楚。",
    "6a26bcf2f0d6ef02acf1d985": "数据估值架构：梯度/Hessian 提取、验证集估值和训练测试流程分区展示。",
    "6a26bcf2f0d6ef02acf1d984": "成员推断示意：用邻域扰动、目标点和决策边界解释鲁棒性问题。",
    "6a26bcf2f0d6ef02acf1d983": "多模态问答模型：视觉、音频、语音三路编码后由查询连接器融合。",
    "6a26bcf2f0d6ef02acf1d982": "视频换脸框架：静态图与视频序列并行输入，突出身份与目标视频分支。",
    "6a26bcf2f0d6ef02acf1d981": "推荐推理流水线：离线画像生成和在线检索/偏好建模分两段展示。",
    "6a26bcf2f0d6ef02acf1d980": "自适应视觉推理：先低清判断，必要时请求高清局部信息继续推理。",
    "6a26bcf2f0d6ef02acf1d97f": "自蒸馏训练框架：教师/学生双网络、寄存器 token 和特征去噪并列。",
    "6a26bcf2f0d6ef02acf1d97e": "迭代感知推理：多轮选择高置信视觉区域，体现由粗到细的注意力路径。",
    "6a26bcf2f0d6ef02acf1d97d": "视频检索增强：查询拆解、辅助文本生成、外部检索和回答生成串联。",
    "6a26bcf2f0d6ef02acf1d97c": "视频生成记忆框架：空间、工作、情景三类记忆共同条件化扩散模型。",
    "6a26bcf2f0d6ef02acf1d97b": "可迁移生成器训练：源数据优化、扰动样本构造和跨任务评估串联。",
    "6a26bcf2f0d6ef02acf1d97a": "蒸馏方法对比：并列小图解释 VSD 与 VarFlow 的梯度和分布差异。",
    "6a26bcf1f0d6ef02acf1d979": "视频异常推理训练：两阶段 SFT/RL 流程，突出 CoT 视频样本到推理能力。",
    "6a26bcf1f0d6ef02acf1d978": "虚拟试衣精修：偏好评估、模型精修和测试时扩展形成闭环。",
    "6a26bcf1f0d6ef02acf1d977": "伪造检测数据链路：采集、描述生成、MLLM 微调和推理三模块排列。",
    "6a26bcf1f0d6ef02acf1d976": "长文本 CLIP 适配：文本编码器蒸馏、RoPE 扩展和图文对齐训练阶段。",
    "6a26bcf1f0d6ef02acf1d975": "视频压缩编码器：可变长度 patch token 到固定潜变量 token 的重建结构。",
    "6a26bcf1f0d6ef02acf1d974": "高光谱重建框架：三阶段训练、RGB 到 HSI 重建和扩散模块组合。",
    "6a26bcf1f0d6ef02acf1d973": "因果模型形式化：用类别论对象、态射和子对象关系组织抽象概念。",
    "6a26bcf0f0d6ef02acf1d972": "多模态医学分割：多阶段重建、缺失模态补全和编码解码网络组合。",
    "6a26bcf0f0d6ef02acf1d971": "手写公式识别多任务：HMER、树状 CoT、纠错和多任务指令统一训练。",
    "6a26bcf0f0d6ef02acf1d970": "细粒度阴影检测：从输入图到连续透明度 mask，强调局部修正流程。",
    "6a26bcf0f0d6ef02acf1d96f": "HDR 重建流程：合成训练数据和曝光恢复双管线，适合两阶段视觉任务。",
    "6a26bcf0f0d6ef02acf1d96e": "机器人规划架构：指令、场景图、假设树、信念更新和在线规划闭环。",
    "6a26bcf0f0d6ef02acf1d96d": "定理前提选择：树结构搜索与候选前提筛选流程，适合算法流程图。",
    "6a26bcf0f0d6ef02acf1d96c": "强化学习布线：actor 逐步生成直角边序列，critic 评估避障连接质量。",
    "6a26bcf0f0d6ef02acf1d96b": "安全神经元定位：对齐/未对齐模型激活对比，再做动态 patch 验证。",
    "6a26bcf0f0d6ef02acf1d96a": "图像质量数据重塑：参考集合筛选与分布调整提升合成数据泛化。",
    "6a26bcf0f0d6ef02acf1d969": "视觉提示适配器：交叉注意力、傅里叶变换和双分支 adapter 分层展示。",
    "6a26bcf0f0d6ef02acf1d968": "联邦 LoRA 鲁棒微调：本地敏感参数选择、噪声处理和全局聚合流程。",
    "6a26bcf0f0d6ef02acf1d967": "蛋白多尺度图：细粒度运动到粗粒度结构的层级图和两阶段 GNN。",
    "6a26bcf0f0d6ef02acf1d966": "图任务统一推理：把节点/边/图任务转成带语义特征的知识图谱推断。",
    "6a26bcf0f0d6ef02acf1d965": "血管三维建模：中心线/点云输入、样条构造和 SE(3) 图网络处理。",
    "6a26bcf0f0d6ef02acf1d964": "交通拓扑感知：车道端点检测、几何注意力和拓扑头融合。",
    "6a26bcf0f0d6ef02acf1d963": "模型安全评测意识：用探针和 steering 展示假设任务与评测场景分歧。",
    "6a26bcf0f0d6ef02acf1d962": "量子线路强化学习：张量网络初始化、brickwork 电路和 RL 搜索状态。",
    "6a26bcf0f0d6ef02acf1d961": "数据选择方法：源/目标分布对齐与单语义神经元活跃度计算并列。",
    "6a26bcf0f0d6ef02acf1d960": "时序 VLM 偏差发现：找出静态特征偏差导致的时序预测错误。",
    "6a26bcf0f0d6ef02acf1d95f": "半监督三方协同：双学生、互补视图、对抗扰动和伪标签元学习。",
    "6a26bcf0f0d6ef02acf1d95e": "自主决策系统：指令拆解、深度/地图建模和双节奏动作生成。",
    "6a26bcf0f0d6ef02acf1d95d": "量子参数预测：数据构造、模型训练和跨规模 ansatz 推广三段式。",
    "6a26bcf0f0d6ef02acf1d95c": "提示词元优化：用户 prompt 内循环与系统 prompt 外循环嵌套。",
    "6a26bcf0f0d6ef02acf1d95b": "时间序列框架：左侧数据生成机制，右侧网络架构，适合双栏结构图。",
    "6a26bceff0d6ef02acf1d95a": "分子构象编码：原子/构象层级交互、节点池化和集合表示。",
    "6a26bceff0d6ef02acf1d959": "注意力初始化对比：传统生成式初始化与结构化初始化并排说明。",
    "6a26bceff0d6ef02acf1d958": "多 GPU 通信拓扑：按本地 rank 形成子环，突出跨团队 attention 传递。",
    "6a26bceff0d6ef02acf1d957": "合成图检测：LLaVA 主干、多粒度特征和伪造痕迹解释模块。",
    "6a26bceff0d6ef02acf1d956": "动态场景重建：脉冲相机流到 4D Gaussian 渲染的传感器-场景链路。",
    "6a26bceff0d6ef02acf1d955": "Transformer 频谱注意力：在每层自注意力里加入谱条件控制。",
    "6a26bceff0d6ef02acf1d954": "推理加速：小模型先猜推理步骤，大模型只在关键处评估或接管。",
    "6a26bceff0d6ef02acf1d953": "生成式检索架构：稀疏 ID、密集表示和 coarse-to-fine 生成级联。",
    "6a26bceff0d6ef02acf1d952": "推理服务系统：把时间复用改为空间复用，拆分模型组件并行服务。",
    "6a26bceff0d6ef02acf1d951": "二部图网络：拓扑子图提取、符号流建模和大规模图可扩展处理。",
    "6a26bceff0d6ef02acf1d950": "多智能体决策：把高维动作分解为连续优势模块，展示顺序决策链。",
    "6a26bceff0d6ef02acf1d94f": "动态加权自训练：三重自适应机制平滑从源域到目标域迁移。",
    "6a26bceff0d6ef02acf1d94e": "文本匿名化闭环：LLM 生成匿名轨迹、属性推断和效用评估相互博弈。",
    "6a26bceff0d6ef02acf1d94d": "3D 场景合成：点云与文本描述按空间关系组合，形成对比学习样本。"
  ]

  static func diagramBrief(title: String, summary: String) -> String {
    let haystack = "\(title) \(summary)".lowercased()
    let name = frameworkName(from: title)

    if haystack.containsAny(["video-rag", "retrieval request", "auxiliary text"]) {
      return "\(name)视频检索增强：把查询拆解、辅助文本检索和生成回答串成流水线。"
    }
    if haystack.containsAny(["recommendation", "recommender", "user profile"]) {
      return "\(name)推荐系统流程：突出用户画像、候选召回、偏好建模和排序模块。"
    }
    if haystack.containsAny(["multimodal", "multi-modal", "vision", "audio", "speech"]) {
      return "\(name)多模态架构：多路输入分别编码，再通过融合模块服务下游任务。"
    }
    if haystack.containsAny(["diffusion", "generator", "distillation"]) {
      return "\(name)生成模型流程：展示训练/蒸馏、条件输入和渲染生成之间的关系。"
    }
    if haystack.containsAny(["graph", "topology", "tree"]) {
      return "\(name)结构推理图：突出节点关系、层级结构和推理路径。"
    }
    if haystack.containsAny(["training", "stage", "fine-tuning", "self-training"]) {
      return "\(name)训练流程图：按阶段展示数据、模型更新和评估闭环。"
    }
    return "\(name)方法框架图：适合展示模块分工、输入输出和关键连接关系。"
  }

  static func plotBrief(title: String, summary: String) -> String {
    let haystack = "\(title) \(summary)".lowercased()
    let form = plotForm(from: haystack)
    let focus = plotFocus(from: haystack)

    if let subplotCount = subplotCount(from: haystack), subplotCount > 1 {
      return "\(form)：\(subplotCount) 个子图并列展示，适合\(focus)的横向对照。"
    }
    if haystack.contains("inset") || haystack.contains("zoom") {
      return "\(form)：主图看整体趋势，嵌入小图放大局部差异，适合\(focus)。"
    }
    return "\(form)：突出\(focus)，适合作为统计图布局参考。"
  }

  static func frameworkName(from title: String) -> String {
    let title = title.replacingOccurrences(of: "\n", with: " ")
    let patterns = [
      #"(?i)\b(?:of|for)\s+(?:the\s+)?([A-Z][A-Za-z0-9-]{2,})\b"#,
      #"(?i)\b([A-Z][A-Za-z0-9-]{2,})\s+(?:framework|model|pipeline|architecture|system)\b"#
    ]

    for pattern in patterns {
      guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
      let range = NSRange(title.startIndex..<title.endIndex, in: title)
      guard let match = regex.firstMatch(in: title, range: range),
            let swiftRange = Range(match.range(at: 1), in: title) else { continue }
      let candidate = String(title[swiftRange])
      if !["Figure", "Overview", "Workflow"].contains(candidate) {
        return "\(candidate) "
      }
    }
    return ""
  }

  static func plotForm(from haystack: String) -> String {
    if haystack.contains("bubble heatmap") || haystack.contains("dot matrix heatmap") { return "气泡热力图" }
    if haystack.contains("heatmap") { return "热力图" }
    if haystack.contains("radar chart") { return "雷达图" }
    if haystack.contains("treemap") { return "矩形树图" }
    if haystack.contains("nested pie") || haystack.contains("double layer donut") { return "双层环形图" }
    if haystack.contains("donut") { return "环形图" }
    if haystack.contains("pie chart") { return "饼图" }
    if haystack.contains("3d bar") { return "三维柱状图" }
    if haystack.contains("stacked area") { return "堆叠面积图" }
    if haystack.contains("diverging bar") { return "发散条形图" }
    if haystack.contains("horizontal stacked bar") || haystack.contains("stacked horizontal bar") { return "横向堆叠条形图" }
    if haystack.contains("stacked bar") { return "堆叠柱状图" }
    if haystack.contains("grouped bar") { return "分组柱状图" }
    if haystack.contains("error bar") { return "误差棒图" }
    if haystack.contains("bubble chart") { return "气泡图" }
    if haystack.contains("scatter plot") { return "散点图" }
    if haystack.contains("line chart") { return "折线图" }
    if haystack.contains("bar chart") { return "柱状图" }
    return "统计图"
  }

  static func plotFocus(from haystack: String) -> String {
    if haystack.containsAny(["parameters", "nmae", "model", "f1", "accuracy", "computational"]) {
      return "比较模型规模、性能和计算成本"
    }
    if haystack.containsAny(["politic", "party", "policy", "approval", "strategy"]) {
      return "比较政策、群体或阵营指标"
    }
    if haystack.containsAny(["treatment", "patient", "health", "cognitive", "mental"]) {
      return "比较医疗健康指标与干预效果"
    }
    if haystack.containsAny(["cloud", "technology", "platform", "social media", "streaming"]) {
      return "比较平台、技术类别和使用表现"
    }
    if haystack.containsAny(["crop", "agricultural", "rainfall", "temperature", "co2", "energy", "pollutant"]) {
      return "呈现环境、能源或农业指标的变化"
    }
    if haystack.containsAny(["revenue", "profit", "market", "gdp", "patent"]) {
      return "比较商业、市场或经济指标"
    }
    if haystack.containsAny(["destination", "tourism", "city", "region"]) {
      return "比较地点、区域或目的地特征"
    }
    if haystack.containsAny(["year", "month", "iterations", "time", "over time"]) {
      return "呈现时间序列趋势和局部变化"
    }
    return "比较多组指标、类别占比或变量关系"
  }

  static func subplotCount(from haystack: String) -> Int? {
    guard let regex = try? NSRegularExpression(pattern: #"a figure with (\d+) subplots"#) else { return nil }
    let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
    guard let match = regex.firstMatch(in: haystack, range: range),
          let swiftRange = Range(match.range(at: 1), in: haystack) else { return nil }
    return Int(haystack[swiftRange])
  }
}

private extension String {
  func containsAny(_ needles: [String]) -> Bool {
    needles.contains { contains($0) }
  }
}
