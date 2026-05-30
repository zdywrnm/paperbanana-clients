"use strict";
const API_BASE = 'https://yifbnnzrwmxn.sealoshzh.site';
const API_ENDPOINT = `${API_BASE}/paperbanana-api`;
const AUTH_BASE = `${API_BASE}/api/auth`;
const LOCAL_JOBS_KEY = 'paperbanana_mini_jobs';
const AUTH_COOKIE_KEY = 'paperbanana_auth_cookie';
const DATA_IMAGE_PATTERN = /^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/;
const PROVIDERS = [
    {
        id: 'bailian',
        label: '阿里百炼',
        keyPlaceholder: 'sk-...',
        mainModel: 'qwen3.7-max',
        imageModel: 'wan2.7-image-pro',
        mainModels: [
            { label: '通义千问 / Qwen3.7 Max', value: 'qwen3.7-max' },
            { label: '通义千问 / Qwen3.7 Max 2026-05-20', value: 'qwen3.7-max-2026-05-20' },
            { label: '通义千问 / Qwen3.6 Plus', value: 'qwen3.6-plus' },
            { label: '通义千问 / Qwen3.6 Flash', value: 'qwen3.6-flash' },
            { label: '通义千问 / Qwen Plus Latest', value: 'qwen-plus-latest' },
            { label: '通义千问 / Qwen Max Latest', value: 'qwen-max-latest' },
            { label: '通义千问 / Qwen Flash', value: 'qwen-flash' },
            { label: '百炼第三方 / DeepSeek V4 Pro', value: 'deepseek-v4-pro' },
            { label: '百炼第三方 / DeepSeek V4 Flash', value: 'deepseek-v4-flash' },
            { label: '百炼第三方 / Kimi K2.6', value: 'kimi-k2.6' },
            { label: '百炼第三方 / GLM 5.1', value: 'glm-5.1' },
            { label: '百炼第三方 / MiniMax M2.7', value: 'MiniMax-M2.7' },
            { label: '百炼第三方 / MiMo V2.5 Pro', value: 'mimo-v2.5-pro' },
        ],
        imageModels: [
            { label: '通义万相 / Wan 2.7 Image Pro', value: 'wan2.7-image-pro' },
            { label: '通义万相 / Wan 2.7 Image', value: 'wan2.7-image' },
            { label: '通义万相 / Wan 2.6 Image', value: 'wan2.6-image' },
            { label: '通义万相 / Wan 2.6 T2I', value: 'wan2.6-t2i' },
            { label: '通义万相 / Wan 2.5 T2I Preview', value: 'wan2.5-t2i-preview' },
            { label: '通义万相 / Wan 2.2 T2I Plus', value: 'wan2.2-t2i-plus' },
            { label: '通义万相 / Wan 2.2 T2I Flash', value: 'wan2.2-t2i-flash' },
            { label: '通义千问 Image / Qwen Image 2.0 Pro', value: 'qwen-image-2.0-pro' },
            { label: '通义千问 Image / Qwen Image 2.0', value: 'qwen-image-2.0' },
            { label: '通义千问 Image / Qwen Image Max', value: 'qwen-image-max' },
            { label: '通义千问 Image / Qwen Image Plus', value: 'qwen-image-plus' },
            { label: '通义千问 Image / Qwen Image', value: 'qwen-image' },
            { label: 'Z-Image / Z-Image Turbo', value: 'z-image-turbo' },
        ],
        guideSteps: ['打开阿里云百炼控制台', '进入 API Key 页面创建密钥', '复制 sk- 开头密钥到小程序'],
    },
    {
        id: 'openrouter',
        label: 'OpenRouter',
        keyPlaceholder: 'sk-or-v1-...',
        mainModel: 'openrouter/openai/gpt-5.5',
        imageModel: 'openrouter/openai/gpt-5.4-image-2',
        mainModels: [
            { label: 'OpenAI / GPT-5.5', value: 'openrouter/openai/gpt-5.5' },
            { label: 'OpenAI / GPT-5.5 Pro', value: 'openrouter/openai/gpt-5.5-pro' },
            { label: 'OpenAI / GPT-5.4', value: 'openrouter/openai/gpt-5.4' },
            { label: 'OpenAI / GPT-5.4 Pro', value: 'openrouter/openai/gpt-5.4-pro' },
            { label: 'OpenAI / GPT-5.4 Mini', value: 'openrouter/openai/gpt-5.4-mini' },
            { label: 'OpenAI / GPT-5.4 Nano', value: 'openrouter/openai/gpt-5.4-nano' },
            { label: 'OpenAI / GPT Chat Latest', value: 'openrouter/openai/gpt-chat-latest' },
            { label: 'OpenAI / GPT-5.3 Chat', value: 'openrouter/openai/gpt-5.3-chat' },
            { label: 'OpenAI / GPT Latest', value: 'openrouter/~openai/gpt-latest' },
            { label: 'OpenAI / GPT Mini Latest', value: 'openrouter/~openai/gpt-mini-latest' },
            { label: 'Anthropic / Claude Opus 4.8', value: 'openrouter/anthropic/claude-opus-4.8' },
            { label: 'Anthropic / Claude Opus 4.8 Fast', value: 'openrouter/anthropic/claude-opus-4.8-fast' },
            { label: 'Anthropic / Claude Opus 4.7', value: 'openrouter/anthropic/claude-opus-4.7' },
            { label: 'Anthropic / Claude Opus 4.7 Fast', value: 'openrouter/anthropic/claude-opus-4.7-fast' },
            { label: 'Anthropic / Claude Opus Latest', value: 'openrouter/~anthropic/claude-opus-latest' },
            { label: 'Anthropic / Claude Sonnet Latest', value: 'openrouter/~anthropic/claude-sonnet-latest' },
            { label: 'Google / Gemini 3.1 Pro Preview', value: 'openrouter/google/gemini-3.1-pro-preview' },
            { label: 'Google / Gemini 3.5 Flash', value: 'openrouter/google/gemini-3.5-flash' },
            { label: 'Google / Gemini 3.1 Flash Lite', value: 'openrouter/google/gemini-3.1-flash-lite' },
            { label: 'Google / Gemini 3.1 Flash Lite Preview', value: 'openrouter/google/gemini-3.1-flash-lite-preview' },
            { label: 'Google / Gemini Pro Latest', value: 'openrouter/~google/gemini-pro-latest' },
            { label: 'Google / Gemini Flash Latest', value: 'openrouter/~google/gemini-flash-latest' },
            { label: 'Qwen / Qwen3.7 Max', value: 'openrouter/qwen/qwen3.7-max' },
            { label: 'Qwen / Qwen3.6 Plus', value: 'openrouter/qwen/qwen3.6-plus' },
            { label: 'Qwen / Qwen3.6 Flash', value: 'openrouter/qwen/qwen3.6-flash' },
            { label: 'Qwen / Qwen3.6 Max Preview', value: 'openrouter/qwen/qwen3.6-max-preview' },
            { label: 'Qwen / Qwen3.5 Plus 2026-04-20', value: 'openrouter/qwen/qwen3.5-plus-20260420' },
            { label: 'DeepSeek / DeepSeek V4 Pro', value: 'openrouter/deepseek/deepseek-v4-pro' },
            { label: 'DeepSeek / DeepSeek V4 Flash', value: 'openrouter/deepseek/deepseek-v4-flash' },
            { label: 'xAI / Grok 4.3', value: 'openrouter/x-ai/grok-4.3' },
            { label: 'xAI / Grok 4.20', value: 'openrouter/x-ai/grok-4.20' },
            { label: 'xAI / Grok 4.20 Multi-Agent', value: 'openrouter/x-ai/grok-4.20-multi-agent' },
            { label: 'xAI / Grok Build 0.1', value: 'openrouter/x-ai/grok-build-0.1' },
            { label: 'Moonshot / Kimi K2.6', value: 'openrouter/moonshotai/kimi-k2.6' },
            { label: 'Z.ai / GLM 5.1', value: 'openrouter/z-ai/glm-5.1' },
            { label: 'MiniMax / MiniMax M2.7', value: 'openrouter/minimax/minimax-m2.7' },
            { label: 'StepFun / Step 3.7 Flash', value: 'openrouter/stepfun/step-3.7-flash' },
        ],
        imageModels: [
            { label: 'OpenAI / GPT-5.4 Image 2', value: 'openrouter/openai/gpt-5.4-image-2' },
            { label: 'OpenAI / GPT-5 Image', value: 'openrouter/openai/gpt-5-image' },
            { label: 'OpenAI / GPT-5 Image Mini', value: 'openrouter/openai/gpt-5-image-mini' },
            { label: 'Google / Nano Banana 2', value: 'openrouter/google/gemini-3.1-flash-image-preview' },
            { label: 'Google / Nano Banana Pro', value: 'openrouter/google/gemini-3-pro-image-preview' },
            { label: 'Google / Nano Banana', value: 'openrouter/google/gemini-2.5-flash-image' },
            { label: 'xAI / Grok Imagine Image Quality', value: 'openrouter/x-ai/grok-imagine-image-quality' },
            { label: 'Recraft / Recraft V4.1 Pro', value: 'openrouter/recraft/recraft-v4.1-pro' },
            { label: 'Recraft / Recraft V4.1', value: 'openrouter/recraft/recraft-v4.1' },
            { label: 'Recraft / Recraft V4.1 Pro Vector', value: 'openrouter/recraft/recraft-v4.1-pro-vector' },
            { label: 'Black Forest Labs / FLUX.2 Pro', value: 'openrouter/black-forest-labs/flux.2-pro' },
            { label: 'Black Forest Labs / FLUX.2 Flex', value: 'openrouter/black-forest-labs/flux.2-flex' },
            { label: 'Black Forest Labs / FLUX.2 Max', value: 'openrouter/black-forest-labs/flux.2-max' },
            { label: 'ByteDance Seed / Seedream 4.5', value: 'openrouter/bytedance-seed/seedream-4.5' },
            { label: 'Sourceful / Riverflow V2 Pro', value: 'openrouter/sourceful/riverflow-v2-pro' },
            { label: 'Sourceful / Riverflow V2 Fast', value: 'openrouter/sourceful/riverflow-v2-fast' },
        ],
        guideSteps: ['登录 OpenRouter', '进入 Keys 页面创建 API Key', '复制 sk-or-v1- 开头密钥'],
    },
    {
        id: 'gemini',
        label: 'Gemini',
        keyPlaceholder: 'AIza...',
        mainModel: 'gemini-3.5-flash',
        imageModel: 'gemini-3.1-flash-image',
        mainModels: [
            { label: 'Gemini 3.5 / Flash', value: 'gemini-3.5-flash' },
            { label: 'Gemini 3.1 / Pro Preview', value: 'gemini-3.1-pro-preview' },
            { label: 'Gemini 3.1 / Pro', value: 'gemini-3.1-pro' },
            { label: 'Gemini 3.1 / Flash Lite', value: 'gemini-3.1-flash-lite' },
            { label: 'Gemini 3.1 / Flash Lite Preview', value: 'gemini-3.1-flash-lite-preview' },
            { label: 'Gemini 3 / Flash', value: 'gemini-3-flash' },
            { label: 'Gemini 3 / Flash Preview', value: 'gemini-3-flash-preview' },
            { label: 'Gemini 3 / Pro Preview', value: 'gemini-3-pro-preview' },
            { label: 'Gemini 2.5 / Pro', value: 'gemini-2.5-pro' },
            { label: 'Gemini 2.5 / Flash', value: 'gemini-2.5-flash' },
            { label: 'Gemini 2.5 / Flash-Lite', value: 'gemini-2.5-flash-lite' },
        ],
        imageModels: [
            { label: 'Nano Banana 2 / Gemini 3.1 Flash Image', value: 'gemini-3.1-flash-image' },
            { label: 'Nano Banana Pro / Gemini 3 Pro Image', value: 'gemini-3-pro-image' },
            { label: 'Nano Banana / Gemini 2.5 Flash Image', value: 'gemini-2.5-flash-image' },
        ],
        guideSteps: ['登录 Google AI Studio', '创建 API key', '复制 AIza 开头密钥'],
    },
    {
        id: 'openai',
        label: 'OpenAI',
        keyPlaceholder: 'sk-...',
        mainModel: 'gpt-5.5',
        imageModel: 'gpt-image-2',
        mainModels: [
            { label: 'GPT-5.5 / GPT-5.5', value: 'gpt-5.5' },
            { label: 'GPT-5.5 / GPT-5.5 Pro', value: 'gpt-5.5-pro' },
            { label: 'GPT-5.4 / GPT-5.4', value: 'gpt-5.4' },
            { label: 'GPT-5.4 / GPT-5.4 Pro', value: 'gpt-5.4-pro' },
            { label: 'GPT-5.4 / GPT-5.4 Mini', value: 'gpt-5.4-mini' },
            { label: 'GPT-5.4 / GPT-5.4 Nano', value: 'gpt-5.4-nano' },
            { label: 'GPT-5 / GPT-5.2', value: 'gpt-5.2' },
            { label: 'GPT-5 / GPT-5.1', value: 'gpt-5.1' },
            { label: 'GPT-5 / GPT-5 Mini', value: 'gpt-5-mini' },
            { label: 'GPT-4.1 / GPT-4.1', value: 'gpt-4.1' },
            { label: 'GPT-4.1 / GPT-4.1 Mini', value: 'gpt-4.1-mini' },
            { label: 'GPT-4o / GPT-4o', value: 'gpt-4o' },
            { label: 'GPT-4o / GPT-4o Mini', value: 'gpt-4o-mini' },
        ],
        imageModels: [
            { label: 'GPT Image / GPT Image 2', value: 'gpt-image-2' },
            { label: 'GPT Image / GPT Image 1.5', value: 'gpt-image-1.5' },
            { label: 'GPT Image / GPT Image 1', value: 'gpt-image-1' },
            { label: 'GPT Image / GPT Image 1 Mini', value: 'gpt-image-1-mini' },
        ],
        guideSteps: ['登录 OpenAI Platform', '创建 secret key', '复制 sk- 开头密钥'],
    },
];
const PIPELINE_OPTIONS = [
    { label: '规划器 + 评审器', value: 'planner_critic' },
    { label: '完整流程', value: 'full' },
    { label: '基础生成', value: 'vanilla' },
];
const ASPECT_RATIO_OPTIONS = [
    { label: '16:9', value: '16:9' },
    { label: '21:9', value: '21:9' },
    { label: '3:2', value: '3:2' },
    { label: '1:1', value: '1:1' },
];
const CANDIDATE_OPTIONS = [
    { label: '1 张', value: 1 },
    { label: '2 张', value: 2 },
    { label: '3 张', value: 3 },
];
const CRITIC_ROUND_OPTIONS = [
    { label: '0 轮', value: 0 },
    { label: '1 轮', value: 1 },
    { label: '2 轮', value: 2 },
];
const INFOGRAPHIC_CATEGORIES = [
    { id: 'method_framework', label: '方法框架图', description: '突出模块、智能体、输入输出和整体系统结构。' },
    { id: 'workflow', label: '流程图', description: '突出步骤顺序、决策节点、循环和执行路径。' },
    { id: 'system_architecture', label: '系统架构图', description: '突出前后端、数据层、模型接口和服务调用关系。' },
    { id: 'mechanism', label: '机制示意图', description: '突出核心原理、变量关系、因果链路和作用机制。' },
    { id: 'comparison', label: '对比图', description: '突出方法、模块、实验设置或方案之间的差异。' },
    { id: 'timeline', label: '时间线/路线图', description: '突出阶段、里程碑、演进过程和计划安排。' },
    { id: 'data_stat', label: '数据统计图', description: '突出指标、趋势、分布、占比或实验结果。' },
    { id: 'concept_map', label: '概念关系图', description: '突出关键词、层级、类别和概念之间的关系。' },
];
const QUICK_START_EXAMPLES = [
    {
        id: 'paper-framework',
        label: '论文框架',
        title: '检索增强多智能体框架',
        category: 'method_framework',
        caption: '图 1：检索增强多智能体学术图示生成框架总览。',
        methodContent: '我们提出一个用于学术图示生成的检索增强多智能体框架。用户输入论文方法内容和目标图注后，系统先由检索器从参考图例库中选取相似案例。规划器将论文文本拆解为模块、箭头关系和视觉层级，风格智能体补充论文发表所需的版式与配色建议。生成器依据视觉规格渲染多张候选图，评审器再检查语义一致性、结构完整性和可读性，并把修改意见反馈给生成器迭代优化。',
        hint: '把方法模块、输入输出、评价环节替换成自己的研究内容。',
    },
    {
        id: 'workflow-service',
        label: '流程说明',
        title: '资料整理与报告生成流程',
        category: 'workflow',
        caption: '图 1：面向资料整理与报告生成的智能工作流。',
        methodContent: '我们构建一个面向资料整理与报告生成的智能工作流。用户先上传课程资料、访谈记录或业务文档，并填写希望得到的报告主题。系统对输入材料进行解析、去重和分段，随后根据主题检索相关片段并生成报告提纲。内容生成模块按照提纲撰写初稿，人工审核节点负责补充事实、修改表达和确认结构。确认后的内容会进入排版与导出模块，最终生成可分享的图文报告或演示材料。',
        hint: '把资料来源、处理步骤、审核节点、交付物换成自己的业务场景。',
    },
];
const STATUS_LABELS = {
    queued: '排队中',
    running: '生成中',
    succeeded: '已完成',
    failed: '失败',
};
Component({
    data: {
        apiBase: API_BASE,
        logoSrc: '/images/logo.png',
        providers: PROVIDERS,
        providerIndex: 0,
        providerLabel: PROVIDERS[0].label,
        providerMainModel: PROVIDERS[0].mainModel,
        providerImageModel: PROVIDERS[0].imageModel,
        providerGuideSteps: PROVIDERS[0].guideSteps,
        mainModelOptions: PROVIDERS[0].mainModels,
        mainModelIndex: getModelIndex(PROVIDERS[0].mainModels, PROVIDERS[0].mainModel),
        mainModelLabel: getModelLabel(PROVIDERS[0].mainModels, PROVIDERS[0].mainModel),
        imageModelOptions: PROVIDERS[0].imageModels,
        imageModelIndex: getModelIndex(PROVIDERS[0].imageModels, PROVIDERS[0].imageModel),
        imageModelLabel: getModelLabel(PROVIDERS[0].imageModels, PROVIDERS[0].imageModel),
        configurationMode: 'simple',
        isAdvancedMode: false,
        modeLabel: '普通模式',
        pipelineOptions: PIPELINE_OPTIONS,
        pipelineIndex: 0,
        pipelineLabel: String(PIPELINE_OPTIONS[0].label),
        aspectRatioOptions: ASPECT_RATIO_OPTIONS,
        aspectRatioIndex: 0,
        aspectRatioLabel: String(ASPECT_RATIO_OPTIONS[0].label),
        candidateOptions: CANDIDATE_OPTIONS,
        candidateIndex: 0,
        candidateLabel: String(CANDIDATE_OPTIONS[0].label),
        criticRoundOptions: CRITIC_ROUND_OPTIONS,
        criticRoundIndex: 1,
        criticRoundLabel: String(CRITIC_ROUND_OPTIONS[1].label),
        mainModelName: PROVIDERS[0].mainModel,
        imageModelName: PROVIDERS[0].imageModel,
        apiKey: '',
        apiKeyPlaceholder: PROVIDERS[0].keyPlaceholder,
        categories: INFOGRAPHIC_CATEGORIES,
        categoryIndex: 0,
        categoryLabel: INFOGRAPHIC_CATEGORIES[0].label,
        categoryDescription: INFOGRAPHIC_CATEGORIES[0].description,
        methodContent: QUICK_START_EXAMPLES[0].methodContent,
        caption: QUICK_START_EXAMPLES[0].caption,
        quickStartExamples: QUICK_START_EXAMPLES,
        healthText: '检测中',
        healthOk: false,
        activeTab: 'generate',
        isGenerateTab: true,
        isRecordsTab: false,
        canSubmit: false,
        isSubmitting: false,
        currentJobId: '',
        job: null,
        localJobs: [],
        accountJobs: [],
        accountJobsError: '',
        accountJobsLoading: false,
        error: '',
        statusLabel: '',
        resultImages: [],
        currentUser: null,
        currentUserEmail: '',
        isLoggedIn: false,
        isAuthChecking: true,
        showAuthPanel: false,
        authMode: 'sign-in',
        authIsSignUp: false,
        authTitle: '登录账号',
        authSubmitText: '登录',
        authToggleText: '没有账号，去注册',
        authEmail: '',
        authPassword: '',
        authName: '',
        authError: '',
        authSubmitting: false,
        authCanSubmit: false,
    },
    lifetimes: {
        attached() {
            this.loadLocalJobs();
            this.refreshCanSubmit();
            this.checkHealth();
            this.refreshSession();
        },
        detached() {
            this.stopPolling();
        },
    },
    methods: {
        switchTab(event) {
            const tab = String(event.currentTarget.dataset.tab || 'generate');
            this.setData({
                activeTab: tab,
                isGenerateTab: tab === 'generate',
                isRecordsTab: tab === 'records',
                showAuthPanel: false,
            });
            if (tab === 'records' && this.data.isLoggedIn) {
                this.loadAccountJobs();
            }
        },
        onProviderChange(event) {
            const providerIndex = readPickerIndex(event.detail.value, PROVIDERS.length);
            const provider = PROVIDERS[providerIndex] || PROVIDERS[0];
            this.setData({
                providerIndex,
                providerLabel: provider.label,
                providerMainModel: provider.mainModel,
                providerImageModel: provider.imageModel,
                providerGuideSteps: provider.guideSteps,
                mainModelOptions: provider.mainModels,
                mainModelIndex: getModelIndex(provider.mainModels, provider.mainModel),
                mainModelLabel: getModelLabel(provider.mainModels, provider.mainModel),
                imageModelOptions: provider.imageModels,
                imageModelIndex: getModelIndex(provider.imageModels, provider.imageModel),
                imageModelLabel: getModelLabel(provider.imageModels, provider.imageModel),
                mainModelName: provider.mainModel,
                imageModelName: provider.imageModel,
                apiKeyPlaceholder: provider.keyPlaceholder,
            });
            this.refreshCanSubmit();
        },
        switchConfigurationMode(event) {
            const requestedMode = String(event.currentTarget.dataset.mode || 'simple');
            const configurationMode = requestedMode === 'advanced' ? 'advanced' : 'simple';
            const isAdvancedMode = configurationMode === 'advanced';
            this.setData({
                configurationMode,
                isAdvancedMode,
                modeLabel: isAdvancedMode ? '专业模式' : '普通模式',
            });
            this.refreshCanSubmit();
        },
        onPipelineChange(event) {
            const pipelineIndex = readPickerIndex(event.detail.value, PIPELINE_OPTIONS.length);
            const option = PIPELINE_OPTIONS[pipelineIndex];
            this.setData({
                pipelineIndex,
                pipelineLabel: option.label,
            });
        },
        onAspectRatioChange(event) {
            const aspectRatioIndex = readPickerIndex(event.detail.value, ASPECT_RATIO_OPTIONS.length);
            const option = ASPECT_RATIO_OPTIONS[aspectRatioIndex];
            this.setData({
                aspectRatioIndex,
                aspectRatioLabel: option.label,
            });
        },
        onCandidateChange(event) {
            const candidateIndex = readPickerIndex(event.detail.value, CANDIDATE_OPTIONS.length);
            const option = CANDIDATE_OPTIONS[candidateIndex];
            this.setData({
                candidateIndex,
                candidateLabel: option.label,
            });
        },
        onCriticRoundChange(event) {
            const criticRoundIndex = readPickerIndex(event.detail.value, CRITIC_ROUND_OPTIONS.length);
            const option = CRITIC_ROUND_OPTIONS[criticRoundIndex];
            this.setData({
                criticRoundIndex,
                criticRoundLabel: option.label,
            });
        },
        onMainModelChange(event) {
            const provider = PROVIDERS[this.data.providerIndex] || PROVIDERS[0];
            const mainModelIndex = readPickerIndex(event.detail.value, provider.mainModels.length);
            const option = provider.mainModels[mainModelIndex] || provider.mainModels[0];
            this.setData({
                mainModelIndex,
                mainModelLabel: option.label,
                mainModelName: option.value,
            });
            this.refreshCanSubmit();
        },
        onImageModelChange(event) {
            const provider = PROVIDERS[this.data.providerIndex] || PROVIDERS[0];
            const imageModelIndex = readPickerIndex(event.detail.value, provider.imageModels.length);
            const option = provider.imageModels[imageModelIndex] || provider.imageModels[0];
            this.setData({
                imageModelIndex,
                imageModelLabel: option.label,
                imageModelName: option.value,
            });
            this.refreshCanSubmit();
        },
        onApiKeyInput(event) {
            this.setData({ apiKey: event.detail.value });
            this.refreshCanSubmit();
        },
        onCategoryChange(event) {
            const categoryIndex = Number(event.detail.value || 0);
            const category = INFOGRAPHIC_CATEGORIES[categoryIndex] || INFOGRAPHIC_CATEGORIES[0];
            this.setData({
                categoryIndex,
                categoryLabel: category.label,
                categoryDescription: category.description,
            });
        },
        onMethodInput(event) {
            this.setData({ methodContent: event.detail.value });
            this.refreshCanSubmit();
        },
        onCaptionInput(event) {
            this.setData({ caption: event.detail.value });
            this.refreshCanSubmit();
        },
        applyExample(event) {
            const exampleId = String(event.currentTarget.dataset.id || '');
            const example = QUICK_START_EXAMPLES.find((item) => item.id === exampleId);
            if (!example)
                return;
            const categoryIndex = INFOGRAPHIC_CATEGORIES.findIndex((item) => item.id === example.category);
            const normalizedCategoryIndex = categoryIndex >= 0 ? categoryIndex : 0;
            const category = INFOGRAPHIC_CATEGORIES[normalizedCategoryIndex];
            this.setData({
                categoryIndex: normalizedCategoryIndex,
                categoryLabel: category.label,
                categoryDescription: category.description,
                methodContent: example.methodContent,
                caption: example.caption,
            });
            this.refreshCanSubmit();
            wx.showToast({ title: '已填入案例', icon: 'success' });
        },
        async checkHealth() {
            try {
                const data = await requestJson({
                    action: 'health',
                });
                const laf = data.laf || {};
                const ok = Boolean(data.ok || laf.ok || data.code === 0);
                this.setData({
                    healthOk: ok,
                    healthText: ok ? '后端可用' : '后端异常',
                });
            }
            catch (error) {
                this.setData({
                    healthOk: false,
                    healthText: formatError(error),
                });
            }
        },
        async submitJob() {
            if (!this.data.canSubmit || this.data.isSubmitting)
                return;
            const provider = PROVIDERS[this.data.providerIndex] || PROVIDERS[0];
            const category = INFOGRAPHIC_CATEGORIES[this.data.categoryIndex] || INFOGRAPHIC_CATEGORIES[0];
            const isAdvancedMode = this.data.configurationMode === 'advanced';
            const pipeline = PIPELINE_OPTIONS[this.data.pipelineIndex] || PIPELINE_OPTIONS[0];
            const aspectRatio = ASPECT_RATIO_OPTIONS[this.data.aspectRatioIndex] || ASPECT_RATIO_OPTIONS[0];
            const candidateCount = CANDIDATE_OPTIONS[this.data.candidateIndex] || CANDIDATE_OPTIONS[0];
            const criticRounds = CRITIC_ROUND_OPTIONS[this.data.criticRoundIndex] || CRITIC_ROUND_OPTIONS[1];
            const mainModelName = isAdvancedMode ? this.data.mainModelName.trim() || provider.mainModel : provider.mainModel;
            const imageModelName = isAdvancedMode ? this.data.imageModelName.trim() || provider.imageModel : provider.imageModel;
            this.setData({
                isSubmitting: true,
                error: '',
                job: null,
                resultImages: [],
                statusLabel: '',
            });
            wx.showLoading({ title: '提交中' });
            try {
                const apiKeys = {
                    openrouter: '',
                    gemini: '',
                    openai: '',
                    bailian: '',
                    [provider.id]: this.data.apiKey.trim(),
                };
                const data = await requestJson({
                    action: 'createJob',
                    configurationMode: this.data.configurationMode,
                    provider: provider.id,
                    apiKeys,
                    methodContent: this.data.methodContent.trim(),
                    caption: this.data.caption.trim(),
                    infographicCategory: category.label,
                    mainModelName,
                    imageModelName,
                    pipelineMode: isAdvancedMode ? pipeline.value : 'planner_critic',
                    aspectRatio: isAdvancedMode ? aspectRatio.value : '16:9',
                    numCandidates: isAdvancedMode ? candidateCount.value : 1,
                    maxCriticRounds: isAdvancedMode ? criticRounds.value : 1,
                });
                const jobId = data.jobId || data.id || '';
                if (!jobId)
                    throw new Error('后端没有返回任务 ID');
                this.setData({
                    currentJobId: jobId,
                    statusLabel: STATUS_LABELS[data.status || 'queued'] || String(data.status || '排队中'),
                });
                wx.hideLoading();
                wx.showToast({ title: '任务已提交', icon: 'success' });
                this.startPolling(jobId);
                if (this.data.isLoggedIn) {
                    this.loadAccountJobs({ silent: true });
                }
            }
            catch (error) {
                this.setData({ error: formatError(error) });
                wx.hideLoading();
                wx.showToast({ title: '提交失败', icon: 'none' });
            }
            finally {
                this.setData({ isSubmitting: false });
            }
        },
        async refreshCurrentJob() {
            if (!this.data.currentJobId)
                return;
            await this.loadJob(this.data.currentJobId);
        },
        async loadJob(jobId) {
            try {
                const data = await requestJson({
                    action: 'getJob',
                    jobId,
                });
                const job = normalizeJob(data.job);
                this.setData({
                    job: toCurrentJobSummary(job),
                    statusLabel: STATUS_LABELS[job.status] || job.status || '未知',
                    resultImages: job.result_images,
                    error: job.status === 'failed' ? formatError(job.error || job.logs_tail || '生成失败') : '',
                });
                this.saveLocalJob(job);
                if (job.status === 'succeeded' || job.status === 'failed') {
                    this.stopPolling();
                    if (this.data.isLoggedIn) {
                        this.loadAccountJobs({ silent: true });
                    }
                }
            }
            catch (error) {
                this.setData({ error: formatError(error) });
            }
        },
        startPolling(jobId) {
            this.stopPolling();
            this.loadJob(jobId);
            const timer = setInterval(() => {
                this.loadJob(jobId);
            }, 3000);
            this.pollingTimer = timer;
        },
        stopPolling() {
            const timer = this.pollingTimer;
            if (timer)
                clearInterval(timer);
            this.pollingTimer = undefined;
        },
        previewImage(event) {
            const url = String(event.currentTarget.dataset.url || '');
            if (!url)
                return;
            const urls = this.data.resultImages.map((image) => image.url).filter(Boolean);
            wx.previewImage({
                current: url,
                urls: urls.length ? urls : [url],
            });
        },
        previewRecordImage(event) {
            const url = String(event.currentTarget.dataset.url || '');
            if (!url)
                return;
            wx.previewImage({ current: url, urls: [url] });
        },
        copyJobId() {
            if (!this.data.currentJobId)
                return;
            wx.setClipboardData({ data: this.data.currentJobId });
        },
        reuseLocalJob(event) {
            const jobId = String(event.currentTarget.dataset.id || '');
            if (!jobId)
                return;
            this.setData({ currentJobId: jobId, error: '' });
            this.switchToGenerate();
            this.startPolling(jobId);
        },
        openAccountJob(event) {
            const jobId = String(event.currentTarget.dataset.id || '');
            if (!jobId)
                return;
            this.setData({ currentJobId: jobId, error: '' });
            this.switchToGenerate();
            this.startPolling(jobId);
        },
        clearLocalJobs() {
            wx.removeStorageSync(LOCAL_JOBS_KEY);
            this.setData({ localJobs: [] });
        },
        loadLocalJobs() {
            const localJobs = readLocalJobs();
            this.setData({ localJobs });
        },
        saveLocalJob(job) {
            if (!job.id)
                return;
            const nextJobs = [toLocalJobSummary(job), ...readLocalJobs().filter((item) => item.id !== job.id)].slice(0, 10);
            wx.setStorageSync(LOCAL_JOBS_KEY, nextJobs);
            this.setData({ localJobs: nextJobs });
        },
        refreshCanSubmit() {
            const hasRequiredModels = !this.data.isAdvancedMode || Boolean(this.data.mainModelName.trim() && this.data.imageModelName.trim());
            const canSubmit = Boolean(this.data.apiKey.trim() &&
                this.data.methodContent.trim().length >= 20 &&
                this.data.caption.trim().length >= 3 &&
                hasRequiredModels &&
                !this.data.isSubmitting);
            this.setData({ canSubmit });
        },
        switchToGenerate() {
            this.setData({
                activeTab: 'generate',
                isGenerateTab: true,
                isRecordsTab: false,
                showAuthPanel: false,
            });
        },
        openAuthPanel() {
            this.setData({
                showAuthPanel: true,
                authError: '',
            });
        },
        closeAuthPanel() {
            this.setData({
                showAuthPanel: false,
                authError: '',
            });
        },
        toggleAuthMode() {
            const nextMode = this.data.authMode === 'sign-in' ? 'sign-up' : 'sign-in';
            this.setAuthMode(nextMode);
        },
        setAuthMode(mode) {
            const isSignUp = mode === 'sign-up';
            this.setData({
                authMode: mode,
                authIsSignUp: isSignUp,
                authTitle: isSignUp ? '注册账号' : '登录账号',
                authSubmitText: isSignUp ? '注册并登录' : '登录',
                authToggleText: isSignUp ? '已有账号，去登录' : '没有账号，去注册',
                authError: '',
            });
            this.refreshAuthCanSubmit();
        },
        onAuthEmailInput(event) {
            this.setData({ authEmail: event.detail.value });
            this.refreshAuthCanSubmit();
        },
        onAuthPasswordInput(event) {
            this.setData({ authPassword: event.detail.value });
            this.refreshAuthCanSubmit();
        },
        onAuthNameInput(event) {
            this.setData({ authName: event.detail.value });
        },
        refreshAuthCanSubmit() {
            this.setData({
                authCanSubmit: Boolean(this.data.authEmail.trim() && this.data.authPassword.length >= 8 && !this.data.authSubmitting),
            });
        },
        async submitAuth() {
            if (!this.data.authCanSubmit || this.data.authSubmitting)
                return;
            this.setData({ authSubmitting: true, authError: '' });
            wx.showLoading({ title: this.data.authIsSignUp ? '注册中' : '登录中' });
            try {
                const email = this.data.authEmail.trim();
                const password = this.data.authPassword;
                if (this.data.authIsSignUp) {
                    await authRequest('/sign-up/email', 'POST', {
                        email,
                        password,
                        name: this.data.authName.trim() || email.split('@')[0] || 'PaperBanana 用户',
                    });
                }
                else {
                    await authRequest('/sign-in/email', 'POST', { email, password });
                }
                await this.refreshSession();
                this.setData({
                    showAuthPanel: false,
                    authPassword: '',
                    activeTab: 'records',
                    isGenerateTab: false,
                    isRecordsTab: true,
                });
                wx.hideLoading();
                wx.showToast({ title: '已登录', icon: 'success' });
                this.loadAccountJobs();
            }
            catch (error) {
                this.setData({ authError: formatError(error) });
                wx.hideLoading();
            }
            finally {
                this.setData({ authSubmitting: false });
                this.refreshAuthCanSubmit();
            }
        },
        async refreshSession() {
            this.setData({ isAuthChecking: true });
            try {
                const session = await authRequest('/get-session', 'GET');
                const user = session && session.user;
                if (user && user.id) {
                    this.setData({
                        currentUser: {
                            id: String(user.id),
                            email: String(user.email || ''),
                            name: String(user.name || ''),
                        },
                        currentUserEmail: String(user.email || ''),
                        isLoggedIn: true,
                        isAuthChecking: false,
                    });
                    if (this.data.isRecordsTab) {
                        this.loadAccountJobs();
                    }
                    return;
                }
                this.setData({
                    currentUser: null,
                    currentUserEmail: '',
                    isLoggedIn: false,
                    isAuthChecking: false,
                    accountJobs: [],
                });
            }
            catch {
                this.setData({
                    currentUser: null,
                    currentUserEmail: '',
                    isLoggedIn: false,
                    isAuthChecking: false,
                    accountJobs: [],
                });
            }
        },
        async signOut() {
            await authRequest('/sign-out', 'POST').catch(() => undefined);
            wx.removeStorageSync(AUTH_COOKIE_KEY);
            this.setData({
                currentUser: null,
                currentUserEmail: '',
                isLoggedIn: false,
                accountJobs: [],
                showAuthPanel: false,
            });
            wx.showToast({ title: '已退出', icon: 'success' });
        },
        async loadAccountJobs(options) {
            if (!this.data.isLoggedIn)
                return;
            if (!options || !options.silent) {
                this.setData({ accountJobsLoading: true, accountJobsError: '' });
            }
            try {
                const data = await requestJson({ action: 'myJobs', limit: 50 });
                const jobs = await hydrateRecordJobs((data.jobs || []).map(normalizeJob));
                this.setData({
                    accountJobs: jobs.map(toRecordJobSummary),
                    accountJobsError: '',
                    accountJobsLoading: false,
                });
            }
            catch (error) {
                this.setData({
                    accountJobsError: formatError(error),
                    accountJobsLoading: false,
                });
            }
        },
    },
});
function readPickerIndex(value, optionCount) {
    const rawValue = Array.isArray(value) ? value[0] : value;
    const index = Number(rawValue || 0);
    if (!Number.isFinite(index) || index < 0 || index >= optionCount)
        return 0;
    return index;
}
function requestJson(body, options = {}) {
    return postJson(API_ENDPOINT, body, options);
}
function authRequest(path, method, data) {
    return new Promise((resolve, reject) => {
        const header = requestHeader(true);
        wx.request({
            url: `${AUTH_BASE}${path}`,
            method,
            timeout: 60000,
            header,
            data,
            success(res) {
                persistCookies(res);
                const responseData = res.data;
                if (res.statusCode < 200 || res.statusCode >= 300) {
                    const body = responseData || {};
                    reject(new Error(body.message || body.error || `HTTP ${res.statusCode}`));
                    return;
                }
                resolve(responseData);
            },
            fail(error) {
                reject(new Error(error.errMsg || '网络请求失败'));
            },
        });
    });
}
function postJson(url, body, options = {}) {
    return new Promise((resolve, reject) => {
        wx.request({
            url,
            method: 'POST',
            timeout: options.timeout || 60000,
            header: requestHeader(options.auth !== false),
            data: body,
            success(res) {
                persistCookies(res);
                const data = res.data || {};
                if (res.statusCode < 200 || res.statusCode >= 300 || (data.code && data.code !== 0)) {
                    reject(new Error(data.error || data.detail || `HTTP ${res.statusCode}`));
                    return;
                }
                resolve(data);
            },
            fail(error) {
                reject(new Error(error.errMsg || '网络请求失败'));
            },
        });
    });
}
function requestHeader(includeAuth) {
    const header = {
        'content-type': 'application/json',
    };
    const cookie = wx.getStorageSync(AUTH_COOKIE_KEY);
    if (includeAuth && typeof cookie === 'string' && cookie) {
        header.Cookie = cookie;
    }
    return header;
}
function persistCookies(res) {
    const cookieLines = [];
    if (Array.isArray(res.cookies)) {
        cookieLines.push(...res.cookies);
    }
    const header = res.header || {};
    const setCookie = header['Set-Cookie'] || header['set-cookie'];
    if (Array.isArray(setCookie)) {
        cookieLines.push(...setCookie);
    }
    else if (typeof setCookie === 'string') {
        cookieLines.push(...splitSetCookieHeader(setCookie));
    }
    if (!cookieLines.length)
        return;
    const cookieMap = parseCookieHeader(wx.getStorageSync(AUTH_COOKIE_KEY) || '');
    cookieLines.forEach((line) => {
        const pair = String(line).split(';')[0];
        const index = pair.indexOf('=');
        if (index <= 0)
            return;
        const name = pair.slice(0, index).trim();
        const value = pair.slice(index + 1).trim();
        if (!value) {
            cookieMap.delete(name);
        }
        else {
            cookieMap.set(name, value);
        }
    });
    const nextCookie = Array.from(cookieMap.entries()).map(([name, value]) => `${name}=${value}`).join('; ');
    if (nextCookie) {
        wx.setStorageSync(AUTH_COOKIE_KEY, nextCookie);
    }
    else {
        wx.removeStorageSync(AUTH_COOKIE_KEY);
    }
}
function splitSetCookieHeader(header) {
    return header.split(/,(?=\s*[^;,=\s]+=[^;,]*)/g).map((item) => item.trim()).filter(Boolean);
}
function parseCookieHeader(header) {
    const cookieMap = new Map();
    header.split(';').forEach((part) => {
        const pair = part.trim();
        const index = pair.indexOf('=');
        if (index <= 0)
            return;
        cookieMap.set(pair.slice(0, index), pair.slice(index + 1));
    });
    return cookieMap;
}
async function hydrateRecordJobs(jobs) {
    const hydrated = await Promise.all(jobs.map(async (job) => {
        const hasImage = job.result_images.some((image) => image.url);
        const hasResult = job.result_image_count > 0 || job.result_images.length > 0;
        if (job.status !== 'succeeded' || hasImage || !hasResult)
            return job;
        try {
            const detail = await requestJson({ action: 'getJob', jobId: job.id });
            return normalizeJob(detail.job);
        }
        catch {
            return job;
        }
    }));
    return hydrated;
}
function normalizeJob(input) {
    const job = (input || {});
    const jobId = String(job.id || job._id || '');
    const methodContent = String(job.method_content || job.methodContent || '');
    const resultImages = (job.result_images || job.resultImages || []).map((image, index) => ({
        filename: String(image.filename || `candidate-${index + 1}`),
        url: resolveImageUrl(String(image.url || ''), jobId, index),
        candidate_id: Number(image.candidate_id != null ? image.candidate_id : image.candidateId != null ? image.candidateId : index),
        mime_type: image.mime_type || image.mimeType || '',
    }));
    const status = String(job.status || 'queued');
    return {
        id: jobId,
        status,
        provider: String(job.provider || ''),
        user_email: String(job.user_email || job.userEmail || ''),
        configuration_mode: String(job.configuration_mode || job.configurationMode || 'simple'),
        method_content: methodContent,
        method_preview: methodContent.length > 86 ? `${methodContent.slice(0, 86)}...` : methodContent,
        caption: String(job.caption || ''),
        infographic_category: String(job.infographic_category || job.infographicCategory || '方法框架图'),
        main_model_name: String(job.main_model_name || job.mainModelName || ''),
        image_gen_model_name: String(job.image_gen_model_name || job.imageModelName || ''),
        aspect_ratio: String(job.aspect_ratio || job.aspectRatio || '16:9'),
        num_candidates: Number(job.num_candidates || job.numCandidates || 0),
        result_image_count: Number(job.result_image_count || job.resultImageCount || resultImages.length || 0),
        result_images: resultImages,
        logs_tail: String(job.logs_tail || (Array.isArray(job.logs) ? job.logs.slice(-10).join('\n') : '')),
        error: String(job.error || ''),
        created_at: job.created_at || job.createdAt,
        updated_at: job.updated_at || job.updatedAt,
        completed_at: job.completed_at || job.completedAt,
        created_text: formatDate(job.created_at || job.createdAt),
        status_text: STATUS_LABELS[status] || status || '未知',
    };
}
function resolveImageUrl(url, jobId = 'image', index = 0) {
    if (!url)
        return '';
    if (/^https?:\/\//i.test(url))
        return url;
    if (/^data:image\//i.test(url))
        return cacheDataImage(url, jobId, index);
    return `${API_BASE}${url}`;
}
function cacheDataImage(dataUrl, jobId, index) {
    const match = dataUrl.match(DATA_IMAGE_PATTERN);
    if (!match)
        return '';
    const [, mimeType, base64Data] = match;
    const extension = imageExtension(mimeType);
    const safeJobId = jobId.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 80) || 'image';
    const filePath = `${wx.env.USER_DATA_PATH}/paperbanana-${safeJobId}-${index}.${extension}`;
    try {
        wx.getFileSystemManager().writeFileSync(filePath, base64Data, 'base64');
        return filePath;
    }
    catch (error) {
        console.warn('Failed to cache generated image', error);
        return '';
    }
}
function imageExtension(mimeType) {
    if (mimeType.includes('jpeg') || mimeType.includes('jpg'))
        return 'jpg';
    if (mimeType.includes('webp'))
        return 'webp';
    return 'png';
}
function getModelIndex(options, value) {
    const index = options.findIndex((option) => option.value === value);
    return index >= 0 ? index : 0;
}
function getModelLabel(options, value) {
    const option = options.find((item) => item.value === value);
    return option ? option.label : value;
}
function readLocalJobs() {
    const jobs = wx.getStorageSync(LOCAL_JOBS_KEY);
    return Array.isArray(jobs) ? jobs.map(normalizeJob).filter((job) => job.id).map(toLocalJobSummary) : [];
}
function toCurrentJobSummary(job) {
    return {
        ...job,
        method_content: '',
        result_images: [],
        logs_tail: '',
    };
}
function toRecordJobSummary(job) {
    return {
        ...job,
        method_content: '',
        logs_tail: '',
    };
}
function toLocalJobSummary(job) {
    return {
        ...job,
        method_content: '',
        result_images: [],
        logs_tail: '',
    };
}
function formatError(error) {
    const message = error instanceof Error ? error.message : String(error || '');
    if (message.includes('Invalid email or password'))
        return '邮箱或密码不正确。';
    if (message.includes('Invalid origin') || message.includes('Origin not allowed')) {
        return '登录请求被后端来源校验拦截。需要在网关的 FRONTEND_ORIGINS / Better Auth trustedOrigins 放行微信小程序来源后重新部署。';
    }
    if (message.includes('User already exists'))
        return '这个邮箱已经注册，请直接登录。';
    if (message.includes('Missing API key'))
        return '缺少所选模型接口的 API Key。';
    if (message.includes('Incorrect API key') || message.includes('apikey-error')) {
        return 'API Key 不正确。请确认当前选择的模型服务和填写的密钥匹配；如果选择阿里百炼，需要填写百炼控制台创建的 sk- 开头 API Key。';
    }
    if (message.includes('Please log in') || message.includes('请先登录') || message.includes('Unauthorized'))
        return '请先登录后再使用任务记录。';
    if (message.includes('Forbidden'))
        return '当前账号没有权限查看这个任务。';
    if (message.includes('url not in domain list'))
        return '请先在小程序后台配置 request 合法域名。';
    if (message.includes('timeout'))
        return '请求超时，请稍后重试。';
    if (message.includes('Invalid gateway token'))
        return '后端网关配置异常。';
    if (message.includes('password'))
        return '密码至少需要 8 位。';
    return message || '操作失败';
}
function formatDate(value) {
    if (!value)
        return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime()))
        return '';
    const pad = (num) => String(num).padStart(2, '0');
    return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
