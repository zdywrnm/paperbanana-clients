import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { createAuthClient } from 'better-auth/react';
import {
  AlertTriangle,
  BookOpen,
  CheckCircle2,
  Download,
  Eye,
  ExternalLink,
  FileText,
  Image as ImageIcon,
  KeyRound,
  Loader2,
  RefreshCcw,
  Send,
  Settings2,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import './styles.css';

const logoUrl = '/logo.svg';
const API_BASE_DEFAULT = import.meta.env.VITE_API_BASE || '';
const BACKEND_MODE = import.meta.env.VITE_BACKEND_MODE || '';
const AUTH_REQUIRED = import.meta.env.VITE_AUTH_REQUIRED === 'true';
const AUTH_BASE_DEFAULT = import.meta.env.VITE_AUTH_BASE || (BACKEND_MODE === 'gateway' ? API_BASE_DEFAULT : '');
const AUTH_ENABLED = AUTH_REQUIRED || import.meta.env.VITE_AUTH_ENABLED === 'true' || Boolean(import.meta.env.VITE_AUTH_BASE);
const AUTH_UI_ENABLED = import.meta.env.VITE_AUTH_UI !== 'false';

const authClient = createAuthClient({
  ...(AUTH_BASE_DEFAULT ? { baseURL: AUTH_BASE_DEFAULT } : {}),
  fetchOptions: {
    credentials: 'include',
  },
});

const PROVIDERS = {
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

const SAMPLE_METHOD = `我们提出一个用于学术图示生成的检索增强多智能体框架。检索器会先从参考库中选择相关图例，规划器再把论文方法部分和目标图注转换为详细的视觉规格。风格智能体会补充适合论文发表的版式与配色建议，生成器据此渲染多张候选图，评审器则迭代检查语义一致性与可读性。`;

const INFOGRAPHIC_CATEGORIES = [
  ['method_framework', '方法框架图', '突出模块、智能体、输入输出和整体系统结构。'],
  ['workflow', '流程图', '突出步骤顺序、决策节点、循环和执行路径。'],
  ['system_architecture', '系统架构图', '突出前后端、数据层、模型接口和服务调用关系。'],
  ['mechanism', '机制示意图', '突出核心原理、变量关系、因果链路和作用机制。'],
  ['comparison', '对比图', '突出不同方法、模块、实验设置或方案之间的差异。'],
  ['timeline', '时间线/路线图', '突出阶段、里程碑、演进过程和计划安排。'],
  ['data_stat', '数据统计图', '突出指标、趋势、分布、占比或实验结果。'],
  ['concept_map', '概念关系图', '突出关键词、层级、类别和概念之间的关系。'],
];

const QUICK_START_EXAMPLES = [
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

const STATUS_LABELS = {
  queued: '排队中',
  running: '生成中',
  succeeded: '已完成',
  failed: '失败',
};

function useAuthSession() {
  const [session, setSession] = useState(null);
  const [isPending, setIsPending] = useState(AUTH_ENABLED);
  const [error, setError] = useState(null);

  async function refresh() {
    if (!AUTH_ENABLED) {
      setIsPending(false);
      setSession(null);
      setError(null);
      return null;
    }
    setIsPending(true);
    const { data, error: authError } = await authClient.getSession();
    setSession(data || null);
    setError(authError || null);
    setIsPending(false);
    return data || null;
  }

  useEffect(() => {
    let cancelled = false;
    if (!AUTH_ENABLED) {
      setIsPending(false);
      return undefined;
    }
    authClient.getSession()
      .then(({ data, error: authError }) => {
        if (cancelled) return;
        setSession(data || null);
        setError(authError || null);
      })
      .finally(() => {
        if (!cancelled) setIsPending(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return { session, isPending, error, refresh };
}

function App() {
  const authSession = useAuthSession();
  const [activeTab, setActiveTab] = useState('generate');
  const [showAuthPanel, setShowAuthPanel] = useState(false);
  const [apiBase, setApiBase] = useState(API_BASE_DEFAULT);
  const [configurationMode, setConfigurationMode] = useState('simple');
  const [provider, setProvider] = useState('bailian');
  const [apiKeys, setApiKeys] = useState({ openrouter: '', gemini: '', openai: '', bailian: '' });
  const [methodContent, setMethodContent] = useState(SAMPLE_METHOD);
  const [caption, setCaption] = useState('图 1：所提出的多智能体学术图示生成框架总览。');
  const [infographicCategory, setInfographicCategory] = useState('method_framework');
  const [mainModelName, setMainModelName] = useState(PROVIDERS.bailian.mainModel);
  const [imageGenModelName, setImageGenModelName] = useState(PROVIDERS.bailian.imageModel);
  const [pipelineMode, setPipelineMode] = useState('demo_planner_critic');
  const [retrievalSetting, setRetrievalSetting] = useState('none');
  const [aspectRatio, setAspectRatio] = useState('16:9');
  const [numCandidates, setNumCandidates] = useState(1);
  const [maxCriticRounds, setMaxCriticRounds] = useState(1);
  const [health, setHealth] = useState(null);
  const [mock, setMock] = useState(false);
  const [currentJobId, setCurrentJobId] = useState('');
  const [job, setJob] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [adminToken, setAdminToken] = useState('');
  const [adminJobs, setAdminJobs] = useState([]);
  const [adminError, setAdminError] = useState('');
  const [userJobs, setUserJobs] = useState([]);
  const [userJobsError, setUserJobsError] = useState('');

  const currentUser = AUTH_ENABLED ? authSession.session?.user : null;
  const authReady = !AUTH_REQUIRED || Boolean(!authSession.isPending && currentUser);
  const providerConfig = PROVIDERS[provider];
  const selectedKey = apiKeys[providerConfig.keyName] || '';
  const apiBaseNormalized = apiBase.replace(/\/$/, '');
  const selectedInfographicCategory = INFOGRAPHIC_CATEGORIES.find(([id]) => id === infographicCategory) || INFOGRAPHIC_CATEGORIES[0];
  const isAdvancedMode = configurationMode === 'advanced';

  useEffect(() => {
    let cancelled = false;
    fetchBackendHealth(apiBaseNormalized)
      .then((data) => {
        if (!cancelled) setHealth(data);
      })
      .catch(() => {
        if (!cancelled) setHealth(null);
      });
    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized]);

  useEffect(() => {
    setMainModelName(PROVIDERS[provider].mainModel);
    setImageGenModelName(PROVIDERS[provider].imageModel);
  }, [provider]);

  useEffect(() => {
    if (!currentJobId) return undefined;
    let cancelled = false;
    const load = async () => {
      try {
        const data = await getJobRequest(apiBaseNormalized, health, currentJobId);
        if (!cancelled) setJob(data);
      } catch (err) {
        if (!cancelled) setError(err.message);
      }
    };
    load();
    const timer = setInterval(load, 3000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [apiBaseNormalized, currentJobId, health]);

  const canSubmit = useMemo(() => {
    const hasKey = selectedKey.trim();
    const canMock = isAdvancedMode && mock && health?.mock_enabled;
    return authReady && (hasKey || canMock) && methodContent.trim().length >= 20 && caption.trim().length >= 3 && !isSubmitting;
  }, [authReady, selectedKey, methodContent, caption, isSubmitting, mock, health, isAdvancedMode]);

  useEffect(() => {
    if (!AUTH_ENABLED || !currentUser) return undefined;
    let cancelled = false;
    loadUserJobs({ silent: true, cancelledRef: () => cancelled });
    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized, currentUser?.id, health]);

  async function submitJob(event) {
    event.preventDefault();
    setError('');
    setIsSubmitting(true);
    setJob(null);
    try {
      const scopedApiKeys = {
        openrouter: '',
        gemini: '',
        openai: '',
        bailian: '',
        [providerConfig.keyName]: selectedKey,
      };
      const payload = {
        configurationMode,
        provider,
        apiKeys: scopedApiKeys,
        taskName: 'diagram',
        methodContent,
        caption,
        infographicCategory: selectedInfographicCategory[1],
        mainModelName: isAdvancedMode ? mainModelName : providerConfig.mainModel,
        imageGenModelName: isAdvancedMode ? imageGenModelName : providerConfig.imageModel,
        pipelineMode: isAdvancedMode ? pipelineMode : 'demo_planner_critic',
        retrievalSetting: isAdvancedMode ? retrievalSetting : 'none',
        aspectRatio: isAdvancedMode ? aspectRatio : '16:9',
        numCandidates: isAdvancedMode ? Number(numCandidates) : 1,
        maxCriticRounds: isAdvancedMode ? Number(maxCriticRounds) : 1,
        mock: isAdvancedMode ? mock : false,
      };
      const created = await createJobRequest(apiBaseNormalized, health, payload);
      setCurrentJobId(created.id);
      if (currentUser) void loadUserJobs({ silent: true });
    } catch (err) {
      setError(err.message);
    } finally {
      setIsSubmitting(false);
    }
  }

  async function loadAdminJobs() {
    setAdminError('');
    try {
      const data = await adminJobsRequest(apiBaseNormalized, health, adminToken);
      setAdminJobs(data.jobs || []);
    } catch (err) {
      setAdminError(err.message);
    }
  }

  async function loadUserJobs(options = {}) {
    if (!AUTH_ENABLED || !currentUser) return;
    if (!options.silent) setUserJobsError('');
    try {
      const data = await userJobsRequest(apiBaseNormalized, health);
      if (options.cancelledRef?.()) return;
      setUserJobs(data.jobs || []);
    } catch (err) {
      if (options.cancelledRef?.()) return;
      setUserJobsError(err.message);
    }
  }

  function applyQuickStartExample(example) {
    setInfographicCategory(example.category);
    setMethodContent(example.methodContent);
    setCaption(example.caption);
  }

  async function handleSignOut() {
    await authClient.signOut();
    await authSession.refresh();
    setShowAuthPanel(false);
    setCurrentJobId('');
    setJob(null);
    setUserJobs([]);
  }

  return (
    <main className="app-shell">
      <header className="paper-header">
        <div className="brand">
          <img className="brand-logo" src={logoUrl} alt="PaperBanana 标志" />
          <div>
            <h1>PaperBanana 工作台</h1>
            <div className="brand-tags">
              <span>多智能体</span>
              <span>学术图示生成</span>
            </div>
          </div>
        </div>
        <div className="header-links">
          <a href="https://huggingface.co/papers/2601.23265" target="_blank" rel="noreferrer">
            <FileText size={16} /> 论文
          </a>
          <a href="https://github.com/dwzhu-pku/PaperBanana" target="_blank" rel="noreferrer">
            <Sparkles size={16} /> GitHub
          </a>
          <a href="https://github.com/zdywrnm/PaperBanana-web/releases/latest" target="_blank" rel="noreferrer">
            <Download size={16} /> Windows 版
          </a>
          {AUTH_UI_ENABLED ? (
            currentUser ? (
              <div className="auth-user">
                <ShieldCheck size={16} />
                <span title={currentUser.email}>{currentUser.email}</span>
                <button type="button" onClick={handleSignOut}>退出</button>
              </div>
            ) : (
              <button type="button" className="auth-entry-button" onClick={() => setShowAuthPanel(true)}>
                <ShieldCheck size={16} /> 登录 / 注册
              </button>
            )
          ) : null}
        </div>
      </header>

      <nav className="paper-tabs">
        <button type="button" className={activeTab === 'generate' ? 'active' : ''} onClick={() => setActiveTab('generate')}>生成候选图</button>
        <button type="button" className={activeTab === 'records' ? 'active' : ''} onClick={() => setActiveTab('records')}>任务记录</button>
      </nav>

      {AUTH_REQUIRED && authSession.isPending ? (
        <section className="auth-panel">
          <Loader2 className="spin" size={24} />
          <p>正在检查登录状态</p>
        </section>
      ) : AUTH_REQUIRED && !currentUser ? (
        <AuthPanel onAuthenticated={authSession.refresh} />
      ) : (
        <>
      {AUTH_UI_ENABLED && showAuthPanel && !currentUser ? (
        AUTH_ENABLED ? (
          <AuthPanel
            onAuthenticated={async () => {
              await authSession.refresh();
              setShowAuthPanel(false);
              setActiveTab('records');
            }}
            onCancel={() => setShowAuthPanel(false)}
          />
        ) : (
          <AuthUnavailablePanel onCancel={() => setShowAuthPanel(false)} />
        )
      ) : null}

      {activeTab === 'generate' ? (
        <>
      <section className="workspace">
        <form className="generator" onSubmit={submitJob}>
          <div className="section-head">
            <Settings2 size={20} />
            <div>
              <h2>生成设置</h2>
              <p>{isAdvancedMode ? '选择模型接口、生成流程和图像渲染参数。' : '选择模型平台并粘贴 API 密钥。'}</p>
            </div>
          </div>

          <div className="field">
            <span>使用模式</span>
            <div className="mode-switch" role="tablist" aria-label="使用模式">
              <button
                type="button"
                className={!isAdvancedMode ? 'active' : ''}
                onClick={() => setConfigurationMode('simple')}
              >
                <Sparkles size={16} />
                <span>普通模式</span>
                <small>平台 + Key</small>
              </button>
              <button
                type="button"
                className={isAdvancedMode ? 'active' : ''}
                onClick={() => setConfigurationMode('advanced')}
              >
                <Settings2 size={16} />
                <span>专业模式</span>
                <small>模型与流程</small>
              </button>
            </div>
          </div>

          <div className="field">
            <span>{isAdvancedMode ? '模型接口' : '模型平台'}</span>
            <div className="segmented">
              {Object.entries(PROVIDERS).map(([id, item]) => (
                <button
                  type="button"
                  key={id}
                  className={provider === id ? 'active' : ''}
                  onClick={() => setProvider(id)}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          <details className="api-keys-panel" open>
            <summary><KeyRound size={17} /> API 密钥</summary>
            <p>不需要填写全部密钥，只填当前选中的模型接口即可。</p>
            <label className="field">
              <span>{providerConfig.label} API 密钥</span>
              <div className="key-input">
                <KeyRound size={18} />
                <input
                  type="password"
                  value={selectedKey}
                  onChange={(event) => setApiKeys({ ...apiKeys, [providerConfig.keyName]: event.target.value })}
                  placeholder={providerConfig.keyPlaceholder}
                  autoComplete="off"
                />
              </div>
            </label>
            <ApiKeyGuide providerConfig={providerConfig} />
          </details>

          {!isAdvancedMode ? (
            <div className="default-summary" aria-label="默认生成配置">
              <span>{providerConfig.mainModel}</span>
              <span>{providerConfig.imageModel}</span>
              <span>规划器 + 评审器</span>
              <span>16:9</span>
            </div>
          ) : (
            <>
              <label className="field">
                <span>后端地址</span>
                <input value={apiBase} onChange={(event) => setApiBase(event.target.value)} placeholder="留空则使用同源后端" />
              </label>

              <div className="settings-grid">
                <Select label="生成流程" value={pipelineMode} onChange={setPipelineMode} options={[
                  ['demo_planner_critic', '规划器 + 评审器'],
                  ['demo_full', '完整流程'],
                  ['vanilla', '基础生成'],
                ]} />
                <Select label="检索设置" value={retrievalSetting} onChange={setRetrievalSetting} options={[
                  ['none', '不使用检索'],
                  ['auto', '自动检索'],
                  ['random', '随机参考'],
                  ['manual', '手动参考'],
                ]} />
                <Select label="画面比例" value={aspectRatio} onChange={setAspectRatio} options={[
                  ['16:9', '16:9'],
                  ['21:9', '21:9'],
                  ['3:2', '3:2'],
                  ['1:1', '1:1'],
                ]} />
                <label className="field compact">
                  <span>候选图数量</span>
                  <input type="number" min="1" max="4" value={numCandidates} onChange={(event) => setNumCandidates(event.target.value)} />
                </label>
                <label className="field compact">
                  <span>评审轮数</span>
                  <input type="number" min="0" max="3" value={maxCriticRounds} onChange={(event) => setMaxCriticRounds(event.target.value)} />
                </label>
              </div>

              <div className="model-grid">
                <label className="field">
                  <span>主模型名称</span>
                  <input value={mainModelName} onChange={(event) => setMainModelName(event.target.value)} />
                </label>
                <label className="field">
                  <span>图像生成模型</span>
                  <input value={imageGenModelName} onChange={(event) => setImageGenModelName(event.target.value)} />
                </label>
              </div>

              {health?.mock_enabled ? (
                <label className="mock-switch">
                  <input type="checkbox" checked={mock} onChange={(event) => setMock(event.target.checked)} />
                  <span>模拟模式</span>
                </label>
              ) : null}
            </>
          )}

          <button className="primary-button" type="submit" disabled={!canSubmit}>
            {isSubmitting ? <Loader2 className="spin" size={18} /> : <Send size={18} />}
            生成候选图
          </button>
          {error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(error)}</div> : null}
        </form>

        <section className="input-results">
          <div className="section-head">
            <FileText size={20} />
            <div>
              <h2>输入内容</h2>
              <p>选择信息图类别，再粘贴论文方法部分和目标图注。</p>
            </div>
          </div>

          <ExampleTemplates examples={QUICK_START_EXAMPLES} onApply={applyQuickStartExample} />

          <div className="input-options">
            <Select
              label="信息图类别"
              value={infographicCategory}
              onChange={setInfographicCategory}
              options={INFOGRAPHIC_CATEGORIES.map(([id, label]) => [id, label])}
            />
            <p>{selectedInfographicCategory[2]}</p>
          </div>

          <div className="two-col input-copy">
            <label className="field">
              <span>论文方法内容</span>
              <textarea value={methodContent} onChange={(event) => setMethodContent(event.target.value)} rows={12} />
            </label>

            <label className="field">
              <span>目标图注</span>
              <textarea value={caption} onChange={(event) => setCaption(event.target.value)} rows={12} />
            </label>
          </div>

          <div className="section-head results-head">
            <ImageIcon size={20} />
            <div>
              <h2>生成结果</h2>
              <p>{currentJobId ? `任务编号 ${currentJobId}` : '提交任务后显示生成结果。'}</p>
            </div>
          </div>
          <JobStatus job={job} apiBase={apiBaseNormalized} />
        </section>
      </section>

      <section className="admin-panel">
        <div className="section-head">
          <Eye size={20} />
          <div>
            <h2>站长观察面板</h2>
            <p>输入 ADMIN_TOKEN 查看最近任务、模型选择和失败原因。</p>
          </div>
        </div>
        <div className="admin-controls">
          <input type="password" value={adminToken} onChange={(event) => setAdminToken(event.target.value)} placeholder="ADMIN_TOKEN" />
          <button type="button" onClick={loadAdminJobs}><RefreshCcw size={17} />刷新</button>
        </div>
        {adminError ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(adminError)}</div> : null}
        <JobTable jobs={adminJobs} showUser apiBase={apiBaseNormalized} />
      </section>
        </>
      ) : (
        <TaskRecordsPanel
          authEnabled={AUTH_ENABLED}
          currentUser={currentUser}
          isPending={authSession.isPending}
          jobs={userJobs}
          error={userJobsError}
          apiBase={apiBaseNormalized}
          onLogin={() => setShowAuthPanel(true)}
          onRefresh={() => loadUserJobs()}
        />
      )}
        </>
      )}
    </main>
  );
}

function ExampleTemplates({ examples, onApply }) {
  return (
    <div className="example-panel">
      <div className="example-panel-head">
        <BookOpen size={16} />
        <span>快速上手案例</span>
      </div>
      <div className="example-grid">
        {examples.map((example) => (
          <button className="example-card" type="button" key={example.id} onClick={() => onApply(example)}>
            <span>{example.label}</span>
            <strong>{example.title}</strong>
            <small>{example.caption}</small>
            <em>{example.hint}</em>
          </button>
        ))}
      </div>
    </div>
  );
}

function AuthPanel({ onAuthenticated, onCancel }) {
  const [mode, setMode] = useState('sign-in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isSignUp = mode === 'sign-up';

  async function submitAuth(event) {
    event.preventDefault();
    setError('');
    setIsSubmitting(true);
    try {
      const action = isSignUp
        ? authClient.signUp.email({
            email,
            password,
            name: name.trim() || email.split('@')[0] || 'PaperBanana 用户',
          })
        : authClient.signIn.email({ email, password });
      const { error: authError } = await action;
      if (authError) throw new Error(authError.message || '登录失败');
      await onAuthenticated();
    } catch (err) {
      setError(err.message);
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="auth-panel">
      <div className="section-head">
        <ShieldCheck size={22} />
        <div>
          <h2>{isSignUp ? '注册账号' : '登录账号'}</h2>
          <p>登录后可以在任务记录里查看历史结果，生成候选图仍可直接使用。</p>
        </div>
      </div>
      <form className="auth-form" onSubmit={submitAuth}>
        {isSignUp ? (
          <label className="field">
            <span>昵称</span>
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="可选" autoComplete="name" />
          </label>
        ) : null}
        <label className="field">
          <span>邮箱</span>
          <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" autoComplete="email" required />
        </label>
        <label className="field">
          <span>密码</span>
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="至少 8 位" autoComplete={isSignUp ? 'new-password' : 'current-password'} required />
        </label>
        <button className="primary-button" type="submit" disabled={isSubmitting || !email || password.length < 8}>
          {isSubmitting ? <Loader2 className="spin" size={18} /> : <ShieldCheck size={18} />}
          {isSignUp ? '注册并登录' : '登录'}
        </button>
        {error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(error)}</div> : null}
      </form>
      <button className="text-button" type="button" onClick={() => setMode(isSignUp ? 'sign-in' : 'sign-up')}>
        {isSignUp ? '已有账号，去登录' : '没有账号，去注册'}
      </button>
      {onCancel ? (
        <button className="text-button muted" type="button" onClick={onCancel}>暂不登录</button>
      ) : null}
    </section>
  );
}

function AuthUnavailablePanel({ onCancel }) {
  return (
    <section className="auth-panel">
      <div className="section-head">
        <ShieldCheck size={22} />
        <div>
          <h2>账号登录</h2>
          <p>账号服务正在配置中。当前不登录也可以正常生成候选图。</p>
        </div>
      </div>
      <div className="login-required-card">
        <AlertTriangle size={22} />
        <div>
          <h3>登录注册暂未接入后端</h3>
          <p>部署 Better Auth 网关并配置认证地址后，这里会开放邮箱和密码登录注册。</p>
        </div>
      </div>
      <button className="text-button muted" type="button" onClick={onCancel}>返回生成候选图</button>
    </section>
  );
}

function TaskRecordsPanel({ authEnabled, currentUser, isPending, jobs, error, apiBase, onLogin, onRefresh }) {
  return (
    <section className="user-jobs-panel">
      <div className="section-head">
        <FileText size={20} />
        <div>
          <h2>我的任务记录</h2>
          <p>任务记录与账号绑定，登录后可以查看自己提交过的任务。</p>
        </div>
      </div>

      {isPending ? (
        <div className="login-required-card">
          <Loader2 className="spin" size={22} />
          <div>
            <h3>正在检查登录状态</h3>
            <p>请稍候。</p>
          </div>
        </div>
      ) : !currentUser ? (
        <div className="login-required-card">
          <ShieldCheck size={22} />
          <div>
            <h3>任务记录需要登录后使用</h3>
            <p>不登录也可以正常生成候选图；登录后，新提交的任务会保存到你的账号记录里。</p>
            {authEnabled ? (
              <button type="button" onClick={onLogin}>登录 / 注册</button>
            ) : (
              <span>账号服务部署后即可使用。</span>
            )}
          </div>
        </div>
      ) : (
        <>
          <div className="admin-controls">
            <input value={currentUser?.email || ''} readOnly aria-label="当前账号" />
            <button type="button" onClick={onRefresh}><RefreshCcw size={17} />刷新</button>
          </div>
          {error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(error)}</div> : null}
          <JobTable jobs={jobs} showUser={false} apiBase={apiBase} />
        </>
      )}
    </section>
  );
}

function JobTable({ jobs, showUser, apiBase }) {
  return (
    <div className="job-table">
      {!jobs.length ? <div className="job-empty">暂无任务记录</div> : null}
      {jobs.map((item) => (
        <div className="job-record-card" key={item.id}>
          <div className="job-record-topline">
            <div className="job-record-meta">
              <span>
                <strong>时间</strong>
                {formatDate(item.created_at || item.createdAt)}
              </span>
              <span>
                <strong>状态</strong>
                <StatusBadge status={item.status} />
              </span>
              <span>
                <strong>模式</strong>
                {formatConfigurationMode(item.configuration_mode)}
              </span>
              <span>
                <strong>类别</strong>
                {item.infographic_category || '方法框架图'}
              </span>
              {showUser ? (
                <span>
                  <strong>用户</strong>
                  <span title={item.user_email}>{item.user_email || '匿名'}</span>
                </span>
              ) : null}
            </div>
          </div>

          <div className="job-models">
            <div>
              <strong>主模型</strong>
              <span title={item.main_model_name}>{item.main_model_name || '未记录'}</span>
            </div>
            <div>
              <strong>图像生成模型</strong>
              <span title={item.image_gen_model_name}>{item.image_gen_model_name || '未记录'}</span>
            </div>
          </div>

          <div className="job-prompts">
            <div>
              <strong>论文方法内容</strong>
              <p>{item.method_content || '未记录'}</p>
            </div>
            <div>
              <strong>目标图注</strong>
              <p>{item.caption || '未记录'}</p>
            </div>
          </div>

          {item.status === 'succeeded' && (item.result_images || []).some((image) => image.url) ? (
            <div className="job-record-images">
              {(item.result_images || []).filter((image) => image.url).map((image) => (
                <figure key={image.filename}>
                  <img src={resolveImageUrl(apiBase, image.url)} alt={`任务结果图 ${image.candidate_id + 1}`} loading="lazy" />
                  <figcaption>结果图 {image.candidate_id + 1}</figcaption>
                </figure>
              ))}
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}

function ApiKeyGuide({ providerConfig }) {
  return (
    <div className="api-key-guide">
      <div className="api-key-guide-head">
        <BookOpen size={16} />
        <span>API Key 申请指南</span>
      </div>
      <ol>
        {providerConfig.guideSteps.map((step) => <li key={step}>{step}</li>)}
      </ol>
      <a href={providerConfig.guideUrl} target="_blank" rel="noreferrer">
        打开 {providerConfig.label} 官方申请/说明页面
        <ExternalLink size={14} />
      </a>
      <p className="api-key-guide-note">密钥只用于本次任务调用模型，不会保存到本站数据库。</p>
    </div>
  );
}

function Select({ label, value, onChange, options }) {
  return (
    <label className="field compact">
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {options.map(([id, text]) => <option key={id} value={id}>{text}</option>)}
      </select>
    </label>
  );
}

function JobStatus({ job, apiBase }) {
  if (!job) {
    return (
      <div className="empty-state">
        <Settings2 size={34} />
        <p>等待新任务</p>
      </div>
    );
  }

  return (
    <div className="job-detail">
      <div className="status-strip">
        <StatusBadge status={job.status} />
        <span>{formatConfigurationMode(job.configuration_mode)}</span>
        <span>{job.provider}</span>
        <span>{job.aspect_ratio}</span>
        <span>{job.num_candidates} 张候选图</span>
      </div>
      {job.error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(job.error)}</div> : null}
      <div className="image-grid">
        {job.result_images.map((image) => (
          <figure key={image.filename}>
            <img src={resolveImageUrl(apiBase, image.url)} alt={`候选图 ${image.candidate_id + 1}`} />
            <figcaption>候选图 {image.candidate_id + 1}</figcaption>
          </figure>
        ))}
      </div>
      {job.status === 'running' || job.status === 'queued' ? (
        <div className="running-line"><Loader2 className="spin" size={17} />生成中，页面会自动刷新。</div>
      ) : null}
      {job.status === 'failed' && job.logs_tail ? <pre className="logs">{job.logs_tail}</pre> : null}
    </div>
  );
}

function StatusBadge({ status }) {
  const className = `status-badge ${status}`;
  const icon = status === 'succeeded' ? <CheckCircle2 size={15} /> : status === 'failed' ? <AlertTriangle size={15} /> : <Loader2 className="spin" size={15} />;
  return <span className={className}>{icon}{STATUS_LABELS[status] || status || '未知'}</span>;
}

async function fetchBackendHealth(apiBase) {
  const candidates = BACKEND_MODE === 'gateway'
    ? [{ mode: 'gateway', url: lafEndpoint(apiBase) }]
    : lafEndpoint(apiBase) === apiBase
    ? [{ mode: 'laf', url: apiBase }]
    : [
        { mode: 'laf', url: lafEndpoint(apiBase) },
        { mode: 'fastapi', url: `${apiBase}/api/health` },
      ];

  let lastError = null;
  for (const candidate of candidates) {
    try {
      const data = await fetchJson(candidate.url);
      if (candidate.mode === 'laf' && data.runtime !== 'laf') throw new Error('当前地址不是 Laf 后端');
      if (candidate.mode === 'gateway' && data.runtime !== 'gateway') throw new Error('当前地址不是认证网关');
      if (candidate.mode === 'fastapi' && !data.ok) throw new Error('当前地址不是 FastAPI 后端');
      return { ...data, backendMode: candidate.mode };
    } catch (err) {
      lastError = err;
    }
  }
  throw lastError || new Error('后端暂时不可用');
}

async function createJobRequest(apiBase, health, payload) {
  if (shouldUseLaf(apiBase, health)) {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'createJob',
        configurationMode: payload.configurationMode,
        provider: payload.provider,
        apiKeys: payload.apiKeys,
        methodContent: payload.methodContent,
        caption: payload.caption,
        infographicCategory: payload.infographicCategory,
        mainModelName: payload.mainModelName,
        imageModelName: payload.imageGenModelName,
        pipelineMode: toLafPipeline(payload.pipelineMode),
        aspectRatio: payload.aspectRatio,
        numCandidates: payload.numCandidates,
        maxCriticRounds: payload.maxCriticRounds,
      }),
    });
    return { id: data.jobId, status: data.status };
  }

  return fetchJson(`${apiBase}/api/jobs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      provider: payload.provider,
      configuration_mode: payload.configurationMode,
      api_keys: payload.apiKeys,
      task_name: payload.taskName,
      method_content: payload.methodContent,
      caption: payload.caption,
      infographic_category: payload.infographicCategory,
      main_model_name: payload.mainModelName,
      image_gen_model_name: payload.imageGenModelName,
      pipeline_mode: payload.pipelineMode,
      retrieval_setting: payload.retrievalSetting,
      aspect_ratio: payload.aspectRatio,
      num_candidates: payload.numCandidates,
      max_critic_rounds: payload.maxCriticRounds,
      mock: payload.mock,
    }),
  });
}

async function getJobRequest(apiBase, health, jobId) {
  if (shouldUseLaf(apiBase, health)) {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'getJob', jobId }),
    });
    return normalizeJob(data.job);
  }
  return fetchJson(`${apiBase}/api/jobs/${jobId}`);
}

async function adminJobsRequest(apiBase, health, adminToken) {
  if (shouldUseLaf(apiBase, health)) {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'adminJobs', adminToken, limit: 50 }),
    });
    return { jobs: (data.jobs || []).map(normalizeJob) };
  }
  return fetchJson(`${apiBase}/api/admin/jobs?limit=50`, {
    headers: { 'x-admin-token': adminToken },
  });
}

async function userJobsRequest(apiBase, health) {
  if (BACKEND_MODE === 'gateway' || health?.backendMode === 'gateway') {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'myJobs', limit: 50 }),
    });
    const jobs = (data.jobs || []).map(normalizeJob);
    return { jobs: await hydrateRecordImages(apiBase, health, jobs) };
  }
  if (!shouldUseLaf(apiBase, health)) {
    const data = await fetchJson(`${apiBase}/api/jobs?scope=mine&limit=50`);
    const jobs = (data.jobs || []).map(normalizeJob);
    return { jobs: await hydrateRecordImages(apiBase, health, jobs) };
  }
  throw new Error('任务记录需要先启用登录网关。');
}

async function hydrateRecordImages(apiBase, health, jobs) {
  return Promise.all(jobs.map(async (job) => {
    const hasImageUrl = (job.result_images || []).some((image) => image.url);
    const hasResult = job.result_image_count > 0 || (job.result_images || []).length > 0;
    if (job.status !== 'succeeded' || hasImageUrl || !hasResult) return job;
    try {
      const detail = await getJobRequest(apiBase, health, job.id);
      return { ...job, ...detail };
    } catch {
      return job;
    }
  }));
}

function shouldUseLaf(apiBase, health) {
  if (BACKEND_MODE === 'fastapi') return false;
  if (BACKEND_MODE === 'gateway') return true;
  if (BACKEND_MODE === 'laf') return true;
  if (health?.backendMode) return health.backendMode === 'laf';
  return apiBase.includes('paperbanana-api') || apiBase === '';
}

function lafEndpoint(apiBase) {
  if (apiBase.endsWith('/paperbanana-api')) return apiBase;
  return `${apiBase}/paperbanana-api`;
}

function toLafPipeline(mode) {
  if (mode === 'demo_full') return 'full';
  if (mode === 'vanilla') return 'vanilla';
  return 'planner_critic';
}

function normalizeJob(job = {}) {
  return {
    id: job.id || job._id,
    status: job.status,
    provider: job.provider,
    user_id: job.user_id || job.userId || '',
    user_email: job.user_email || job.userEmail || '',
    configuration_mode: job.configuration_mode || job.configurationMode || 'advanced',
    method_content: job.method_content || job.methodContent || '',
    caption: job.caption || '',
    infographic_category: job.infographic_category || job.infographicCategory || '方法框架图',
    main_model_name: job.main_model_name || job.mainModelName || '',
    image_gen_model_name: job.image_gen_model_name || job.imageModelName || '',
    pipeline_mode: job.pipeline_mode || job.pipelineMode || '',
    aspect_ratio: job.aspect_ratio || job.aspectRatio || '',
    num_candidates: job.num_candidates || job.numCandidates || 0,
    max_critic_rounds: job.max_critic_rounds || job.maxCriticRounds || 0,
    prompt_char_count: job.prompt_char_count || job.promptCharCount || 0,
    result_image_count: job.result_image_count || job.resultImageCount || 0,
    result_images: (job.result_images || job.resultImages || []).map((image, index) => ({
      filename: image.filename || image.url || `${index}`,
      url: image.url,
      candidate_id: image.candidate_id ?? image.candidateId ?? index,
      mime_type: image.mime_type || image.mimeType || '',
    })),
    logs_tail: job.logs_tail || (Array.isArray(job.logs) ? job.logs.slice(-10).join('\n') : ''),
    error: job.error || '',
    created_at: job.created_at || job.createdAt,
    updated_at: job.updated_at || job.updatedAt,
    started_at: job.started_at || job.startedAt,
    completed_at: job.completed_at || job.completedAt,
  };
}

function resolveImageUrl(apiBase, url) {
  if (!url) return '';
  if (/^(https?:|data:|blob:)/i.test(url)) return url;
  return `${apiBase}${url}`;
}

async function fetchJson(url, options = {}) {
  const fetchOptions = AUTH_ENABLED ? { credentials: 'include', ...options } : options;
  const res = await fetch(url, fetchOptions);
  const text = await res.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { detail: text };
    }
  }
  if (!res.ok || (data.code && data.code !== 0)) {
    throw new Error(data.error || data.detail || `HTTP ${res.status}`);
  }
  return data;
}

function formatErrorMessage(message) {
  if (!message) return '';
  if (message.includes('Missing API key')) return '缺少所选模型接口的 API 密钥。';
  if (message.includes('Please log in') || message.includes('请先登录') || message.includes('Unauthorized')) return '请先登录后再使用生成服务。';
  if (message.includes('password')) return '密码至少需要 8 位。';
  if (message.includes('ADMIN_TOKEN is not configured')) return '管理接口未启用：还没有配置 ADMIN_TOKEN。';
  if (message.includes('Admin API disabled')) return '管理接口未启用。';
  if (message.includes('Backend is unavailable')) return '后端暂时不可用。';
  if (message.includes('HTTP 503')) return '服务暂时不可用，请稍后重试。';
  return message;
}

function formatConfigurationMode(mode) {
  return mode === 'simple' ? '普通模式' : '专业模式';
}

function formatDate(value) {
  if (!value) return '';
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

createRoot(document.getElementById('root')).render(<App />);
