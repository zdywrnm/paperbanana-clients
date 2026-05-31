import { useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  Apple,
  Eye,
  FileText,
  Github,
  Image as ImageIcon,
  KeyRound,
  Loader2,
  MessageCircle,
  MonitorDown,
  RefreshCcw,
  Send,
  Settings2,
  ShieldCheck,
  Smartphone,
  Sparkles,
} from 'lucide-react';
import {
  adminJobsRequest,
  createJobRequest,
  fetchBackendHealth,
  getJobRequest,
  userJobsRequest,
} from '@paperbanana/api';
import {
  API_BASE_DEFAULT,
  AUTH_ENABLED,
  AUTH_REQUIRED,
  AUTH_UI_ENABLED,
  authClient,
  logoUrl,
} from './config';
import {
  INFOGRAPHIC_CATEGORIES,
  PROVIDERS,
  QUICK_START_EXAMPLES,
  SAMPLE_METHOD,
} from './constants';
import ApiKeyGuide from './components/ApiKeyGuide';
import AuthPanel from './components/AuthPanel';
import AuthUnavailablePanel from './components/AuthUnavailablePanel';
import ExampleTemplates from './components/ExampleTemplates';
import JobStatus from './components/JobStatus';
import JobTable from './components/JobTable';
import Select from './components/Select';
import TaskRecordsPanel from './components/TaskRecordsPanel';
import { useAuthSession } from './hooks/useAuthSession';
import { formatErrorMessage } from './utils';

export default function App() {
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
  const defaultMainModelLabel = findModelLabel(providerConfig.mainModels, providerConfig.mainModel);
  const defaultImageModelLabel = findModelLabel(providerConfig.imageModels, providerConfig.imageModel);

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
          <a href="https://github.com/zdywrnm/PaperBanana-clients" target="_blank" rel="noreferrer">
            <Github size={16} /> GitHub
          </a>
          <a href="https://github.com/zdywrnm/PaperBanana-clients/releases/tag/windows-native-v0.1.2" target="_blank" rel="noreferrer">
            <MonitorDown size={16} /> Windows 版
          </a>
          <a href="https://github.com/zdywrnm/PaperBanana-clients/releases/tag/android-preview-0.1.3" target="_blank" rel="noreferrer">
            <Smartphone size={16} /> Android 版
          </a>
          <a href="https://github.com/zdywrnm/PaperBanana-clients/releases/tag/macos-v0.1.0" target="_blank" rel="noreferrer">
            <Apple size={16} /> Mac 版
          </a>
          <a href="https://github.com/zdywrnm/PaperBanana-clients/tree/main/apps/miniprogram" target="_blank" rel="noreferrer">
            <MessageCircle size={16} /> 微信小程序
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
              <span>{defaultMainModelLabel}</span>
              <span>{defaultImageModelLabel}</span>
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
                <Select label="主模型" value={mainModelName} onChange={setMainModelName} options={providerConfig.mainModels} />
                <Select label="图像生成模型" value={imageGenModelName} onChange={setImageGenModelName} options={providerConfig.imageModels} />
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

function findModelLabel(options, value) {
  const option = options.find(([id]) => id === value);
  return option ? option[1] : value;
}
