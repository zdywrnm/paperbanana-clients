export const PROVIDERS = {
  openrouter: {
    label: 'OpenRouter',
    keyName: 'openrouter',
    keyPlaceholder: 'sk-or-v1-...',
    mainModel: 'openrouter/google/gemini-3.1-pro-preview',
    imageModel: 'openrouter/google/gemini-3.1-flash-image-preview',
    guideUrl: 'https://openrouter.ai/settings/keys',
    guideSteps: [
      '登录 OpenRouter，进入 Keys 页面。',
      '点击 Create Key，创建一个新的 API Key。',
      '复制 sk-or-v1- 开头的密钥，粘贴到上方输入框。',
    ],
  },
  gemini: {
    label: 'Gemini',
    keyName: 'gemini',
    keyPlaceholder: 'AIza...',
    mainModel: 'gemini-3.1-pro-preview',
    imageModel: 'gemini-3.1-flash-image-preview',
    guideUrl: 'https://aistudio.google.com/app/apikey',
    guideSteps: [
      '登录 Google AI Studio，进入 API Keys 页面。',
      '点击 Create API key，选择或创建项目。',
      '复制生成的 AIza 开头密钥，粘贴到上方输入框。',
    ],
  },
  openai: {
    label: 'OpenAI',
    keyName: 'openai',
    keyPlaceholder: 'sk-...',
    mainModel: 'gpt-4o',
    imageModel: 'gpt-image-1',
    guideUrl: 'https://platform.openai.com/api-keys',
    guideSteps: [
      '登录 OpenAI Platform，进入 API keys 页面。',
      '点击 Create new secret key，创建密钥。',
      '复制 sk- 开头的密钥，粘贴到上方输入框。',
    ],
  },
  bailian: {
    label: '阿里百炼',
    keyName: 'bailian',
    keyPlaceholder: 'sk-...',
    mainModel: 'qwen-plus',
    imageModel: 'wan2.7-image',
    guideUrl: 'https://help.aliyun.com/zh/model-studio/get-api-key',
    guideSteps: [
      '登录阿里云百炼控制台，确认已开通百炼模型服务。',
      '进入 API Key 页面，点击创建 API Key。',
      '建议选择默认业务空间和全部权限，复制 sk- 开头密钥。',
    ],
  },
};

export const SAMPLE_METHOD = `我们提出一个用于学术图示生成的检索增强多智能体框架。检索器会先从参考库中选择相关图例，规划器再把论文方法部分和目标图注转换为详细的视觉规格。风格智能体会补充适合论文发表的版式与配色建议，生成器据此渲染多张候选图，评审器则迭代检查语义一致性与可读性。`;

export const INFOGRAPHIC_CATEGORIES = [
  ['method_framework', '方法框架图', '突出模块、智能体、输入输出和整体系统结构。'],
  ['workflow', '流程图', '突出步骤顺序、决策节点、循环和执行路径。'],
  ['system_architecture', '系统架构图', '突出前后端、数据层、模型接口和服务调用关系。'],
  ['mechanism', '机制示意图', '突出核心原理、变量关系、因果链路和作用机制。'],
  ['comparison', '对比图', '突出不同方法、模块、实验设置或方案之间的差异。'],
  ['timeline', '时间线/路线图', '突出阶段、里程碑、演进过程和计划安排。'],
  ['data_stat', '数据统计图', '突出指标、趋势、分布、占比或实验结果。'],
  ['concept_map', '概念关系图', '突出关键词、层级、类别和概念之间的关系。'],
];

export const QUICK_START_EXAMPLES = [
  {
    id: 'paper-framework',
    label: '论文框架',
    title: '检索增强多智能体框架',
    category: 'method_framework',
    caption: '图 1：检索增强多智能体学术图示生成框架总览。',
    methodContent: `我们提出一个用于学术图示生成的检索增强多智能体框架。用户输入论文方法内容和目标图注后，系统先由检索器从参考图例库中选取相似案例。规划器将论文文本拆解为模块、箭头关系和视觉层级，风格智能体补充论文发表所需的版式与配色建议。生成器依据视觉规格渲染多张候选图，评审器再检查语义一致性、结构完整性和可读性，并把修改意见反馈给生成器迭代优化。`,
    hint: '把方法模块、输入输出、评价环节替换成自己的研究内容。',
  },
  {
    id: 'workflow-service',
    label: '流程说明',
    title: '资料整理与报告生成流程',
    category: 'workflow',
    caption: '图 1：面向资料整理与报告生成的智能工作流。',
    methodContent: `我们构建一个面向资料整理与报告生成的智能工作流。用户先上传课程资料、访谈记录或业务文档，并填写希望得到的报告主题。系统对输入材料进行解析、去重和分段，随后根据主题检索相关片段并生成报告提纲。内容生成模块按照提纲撰写初稿，人工审核节点负责补充事实、修改表达和确认结构。确认后的内容会进入排版与导出模块，最终生成可分享的图文报告或演示材料。`,
    hint: '把资料来源、处理步骤、审核节点、交付物换成自己的业务场景。',
  },
];

export const STATUS_LABELS = {
  queued: '排队中',
  running: '生成中',
  succeeded: '已完成',
  failed: '失败',
};
