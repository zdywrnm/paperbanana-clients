import { useEffect, useMemo, useRef, useState } from 'react';
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
  MessageSquare,
  MonitorDown,
  RefreshCcw,
  Send,
  Settings2,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Users,
} from 'lucide-react';
import {
  adminFeedbackRequest,
  adminJobsRequest,
  adminStatusRequest,
  adminUsersRequest,
  createJobRequest,
  fetchBackendHealth,
  getJobRequest,
  modelCapabilityRequest,
  prepareReferenceUploadRequest,
  referenceLibraryRequest,
  refineImageRequest,
  submitFeedbackRequest,
  userJobsRequest,
} from '@paperbanana/api';
import {
  API_BASE_DEFAULT,
  AUTH_ENABLED,
  AUTH_REQUIRED,
  AUTH_UI_ENABLED,
  CLIENT_VERSION,
  authClient,
  logoUrl,
} from './config';
import {
  INFOGRAPHIC_CATEGORIES,
  OUTPUT_FORMATS,
  PROVIDERS,
  QUICK_START_EXAMPLES,
  REFERENCE_IMAGE_MODES,
  REFERENCE_IMAGE_LIMITS,
  SAMPLE_METHOD,
} from './constants';
import ApiKeyGuide from './components/ApiKeyGuide';
import AdminFeedbackTable from './components/AdminFeedbackTable';
import AdminUsersTable from './components/AdminUsersTable';
import AuthPanel from './components/AuthPanel';
import AuthUnavailablePanel from './components/AuthUnavailablePanel';
import ExampleTemplates from './components/ExampleTemplates';
import FeedbackDialog from './components/FeedbackDialog';
import JobStatus from './components/JobStatus';
import JobTable from './components/JobTable';
import ReferenceLibraryPanel from './components/ReferenceLibraryPanel';
import ReferenceUploadPanel from './components/ReferenceUploadPanel';
import RefinePanel from './components/RefinePanel';
import Select from './components/Select';
import TaskRecordsPanel from './components/TaskRecordsPanel';
import { useAuthSession } from './hooks/useAuthSession';
import { formatErrorMessage, formatOutputFormat } from './utils';

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
  const [outputFormat, setOutputFormat] = useState('png');
  const [mainModelName, setMainModelName] = useState(PROVIDERS.bailian.mainModel);
  const [imageGenModelName, setImageGenModelName] = useState(PROVIDERS.bailian.imageModel);
  const [referenceVisionModelName, setReferenceVisionModelName] = useState(PROVIDERS.bailian.visionModel);
  const [referenceImageMode, setReferenceImageMode] = useState('auto');
  const [referenceImages, setReferenceImages] = useState([]);
  const [mainModelCapability, setMainModelCapability] = useState(null);
  const referenceImagesRef = useRef([]);
  const [referenceUploadError, setReferenceUploadError] = useState('');
  const [isUploadingReferences, setIsUploadingReferences] = useState(false);
  const [pipelineMode, setPipelineMode] = useState('demo_planner_critic');
  const [retrievalSetting, setRetrievalSetting] = useState('none');
  const [manualReferenceIds, setManualReferenceIds] = useState([]);
  const [referenceLibrary, setReferenceLibrary] = useState([]);
  const [referenceLibraryError, setReferenceLibraryError] = useState('');
  const [isLoadingReferenceLibrary, setIsLoadingReferenceLibrary] = useState(false);
  const [aspectRatio, setAspectRatio] = useState('16:9');
  const [numCandidates, setNumCandidates] = useState(1);
  const [maxCriticRounds, setMaxCriticRounds] = useState(1);
  const [health, setHealth] = useState(null);
  const [mock, setMock] = useState(false);
  const [currentJobId, setCurrentJobId] = useState('');
  const [job, setJob] = useState(null);
  const latestJobRef = useRef(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [isAdmin, setIsAdmin] = useState(false);
  const [adminJobs, setAdminJobs] = useState([]);
  const [adminUsers, setAdminUsers] = useState([]);
  const [adminFeedback, setAdminFeedback] = useState([]);
  const [adminError, setAdminError] = useState('');
  const [adminUsersError, setAdminUsersError] = useState('');
  const [adminFeedbackError, setAdminFeedbackError] = useState('');
  const [userJobs, setUserJobs] = useState([]);
  const [userJobsError, setUserJobsError] = useState('');
  const [showFeedbackDialog, setShowFeedbackDialog] = useState(false);
  const [feedbackError, setFeedbackError] = useState('');
  const [feedbackSuccess, setFeedbackSuccess] = useState(false);
  const [isSubmittingFeedback, setIsSubmittingFeedback] = useState(false);
  const [refineSourceUrl, setRefineSourceUrl] = useState('');
  const [refineInstruction, setRefineInstruction] = useState('');
  const [refineImageSize, setRefineImageSize] = useState('2K');
  const [refineAspectRatio, setRefineAspectRatio] = useState('16:9');
  const [refineJobId, setRefineJobId] = useState('');
  const [refineJob, setRefineJob] = useState(null);
  const [refineError, setRefineError] = useState('');
  const [isSubmittingRefine, setIsSubmittingRefine] = useState(false);

  const currentUser = AUTH_ENABLED ? authSession.session?.user : null;
  const authReady = !AUTH_REQUIRED || Boolean(!authSession.isPending && currentUser);
  const providerConfig = PROVIDERS[provider];
  const selectedKey = apiKeys[providerConfig.keyName] || '';
  const apiBaseNormalized = apiBase.replace(/\/$/, '');
  const selectedInfographicCategory = INFOGRAPHIC_CATEGORIES.find(([id]) => id === infographicCategory) || INFOGRAPHIC_CATEGORIES[0];
  const isAdvancedMode = configurationMode === 'advanced';
  const isPlotCategory = infographicCategory === 'data_stat';
  const defaultMainModelLabel = findModelLabel(providerConfig.mainModels, providerConfig.mainModel);
  const defaultImageModelLabel = findModelLabel(providerConfig.imageModels, providerConfig.imageModel);
  const defaultVisionModelLabel = findModelLabel(providerConfig.visionModels || [], providerConfig.visionModel);
  const activeMainModelName = isAdvancedMode ? mainModelName : providerConfig.mainModel;
  const activeReferenceImageMode = isAdvancedMode ? referenceImageMode : 'auto';
  const mainModelDirectUnsupported = referenceImages.length > 0
    && activeReferenceImageMode === 'main_model'
    && mainModelCapability?.status === 'unsupported';
  const needsReferenceVisionModel = referenceImages.length > 0 && activeReferenceImageMode !== 'main_model';
  const canSelectMainModelDirect = mainModelCapability?.status !== 'unsupported';
  const referenceCapabilityNote = referenceImages.length ? describeReferenceCapability(mainModelCapability) : '';

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
    setReferenceVisionModelName(PROVIDERS[provider].visionModel);
    setReferenceImageMode('auto');
  }, [provider]);

  useEffect(() => {
    if (!referenceImages.length) {
      setMainModelCapability(null);
      return undefined;
    }

    let cancelled = false;
    setMainModelCapability({ status: 'loading', reason: '正在检查主模型能力。' });
    modelCapabilityRequest(apiBaseNormalized, health, provider, activeMainModelName)
      .then((data) => {
        if (!cancelled) setMainModelCapability(data);
      })
      .catch((err) => {
        if (!cancelled) {
          setMainModelCapability({
            status: 'unknown',
            supportsReferenceImages: false,
            reason: err.message || '模型能力暂时无法确认。',
            source: 'client-error',
            cached: false,
          });
        }
      });

    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized, health, provider, activeMainModelName, referenceImages.length]);

  useEffect(() => {
    referenceImagesRef.current = referenceImages;
  }, [referenceImages]);

  useEffect(() => () => {
    referenceImagesRef.current.forEach((image) => URL.revokeObjectURL(image.previewUrl));
  }, []);

  useEffect(() => {
    if (!currentJobId) return undefined;
    let cancelled = false;
    const load = async () => {
      try {
        const data = await getJobRequest(apiBaseNormalized, health, currentJobId);
        if (!cancelled) {
          latestJobRef.current = data;
          setJob(data);
          setError('');
        }
      } catch (err) {
        const latestJob = latestJobRef.current;
        const hasVisibleResult = latestJob?.status === 'succeeded' || (latestJob?.result_images || []).some((image) => image.url);
        if (!cancelled && !hasVisibleResult) setError(err.message);
      }
    };
    load();
    const timer = setInterval(load, 3000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [apiBaseNormalized, currentJobId, health]);

  useEffect(() => {
    if (!refineJobId) return undefined;
    let cancelled = false;
    const load = async () => {
      try {
        const data = await getJobRequest(apiBaseNormalized, health, refineJobId);
        if (!cancelled) {
          setRefineJob(data);
          setRefineError('');
        }
      } catch (err) {
        if (!cancelled) setRefineError(err.message);
      }
    };
    load();
    const timer = setInterval(load, 3000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [apiBaseNormalized, refineJobId, health]);

  useEffect(() => {
    if (!isAdvancedMode || retrievalSetting !== 'manual') return undefined;
    let cancelled = false;
    loadReferenceLibrary({ silent: true, cancelledRef: () => cancelled });
    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized, health, isAdvancedMode, retrievalSetting, isPlotCategory]);

  const canSubmit = useMemo(() => {
    const hasKey = selectedKey.trim();
    const canMock = isAdvancedMode && mock && health?.mock_enabled;
    const hasVisionModel = !needsReferenceVisionModel || Boolean((isAdvancedMode ? referenceVisionModelName : providerConfig.visionModel)?.trim());
    const hasManualReferences = !isAdvancedMode || retrievalSetting !== 'manual' || manualReferenceIds.length > 0;
    return authReady && hasManualReferences && hasVisionModel && !mainModelDirectUnsupported && (hasKey || canMock) && methodContent.trim().length >= 20 && caption.trim().length >= 3 && !isSubmitting && !isUploadingReferences;
  }, [authReady, selectedKey, methodContent, caption, isSubmitting, mock, health, isAdvancedMode, retrievalSetting, manualReferenceIds.length, needsReferenceVisionModel, referenceVisionModelName, providerConfig.visionModel, isUploadingReferences, mainModelDirectUnsupported]);

  const canSubmitRefine = useMemo(() => {
    const hasKey = selectedKey.trim();
    return authReady && hasKey && refineSourceUrl.trim() && refineInstruction.trim().length >= 3 && !isSubmittingRefine;
  }, [authReady, selectedKey, refineSourceUrl, refineInstruction, isSubmittingRefine]);

  useEffect(() => {
    if (!AUTH_ENABLED || !currentUser) return undefined;
    let cancelled = false;
    loadUserJobs({ silent: true, cancelledRef: () => cancelled });
    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized, currentUser?.id, health]);

  useEffect(() => {
    let cancelled = false;
    if (!AUTH_ENABLED || authSession.isPending || !currentUser) {
      setIsAdmin(false);
      return undefined;
    }

    adminStatusRequest(apiBaseNormalized, health)
      .then((data) => {
        if (!cancelled) setIsAdmin(Boolean(data.isAdmin));
      })
      .catch(() => {
        if (!cancelled) setIsAdmin(false);
      });

    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized, authSession.isPending, currentUser?.id, currentUser?.email, health]);

  useEffect(() => {
    if (!isAdmin && activeTab === 'admin') setActiveTab('generate');
  }, [activeTab, isAdmin]);

  useEffect(() => {
    if (!isAdmin) return undefined;
    let cancelled = false;
    loadAdminOverview({ silent: true, cancelledRef: () => cancelled });
    return () => {
      cancelled = true;
    };
  }, [apiBaseNormalized, health, isAdmin]);

  function addReferenceFiles(files) {
    setReferenceUploadError('');
    if (!files.length) return;

    const availableSlots = REFERENCE_IMAGE_LIMITS.maxCount - referenceImages.length;
    if (availableSlots <= 0) {
      setReferenceUploadError(`最多只能上传 ${REFERENCE_IMAGE_LIMITS.maxCount} 张参考图。`);
      return;
    }

    const accepted = [];
    for (const file of files.slice(0, availableSlots)) {
      const mimeType = normalizeReferenceMimeType(file);
      if (!REFERENCE_IMAGE_LIMITS.mimeTypes.includes(mimeType)) {
        setReferenceUploadError('参考图仅支持 PNG、JPG、WebP 或 SVG。');
        continue;
      }
      if (file.size > REFERENCE_IMAGE_LIMITS.maxBytes) {
        setReferenceUploadError('单张参考图不能超过 5MB。');
        continue;
      }
      accepted.push({
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
        file,
        filename: file.name || `reference-${referenceImages.length + accepted.length + 1}.${extensionForMimeType(mimeType)}`,
        mimeType,
        size: file.size,
        previewUrl: URL.createObjectURL(file),
      });
    }

    if (files.length > availableSlots) {
      setReferenceUploadError(`最多只能上传 ${REFERENCE_IMAGE_LIMITS.maxCount} 张参考图，已忽略多余文件。`);
    }

    if (accepted.length) {
      setReferenceImages((current) => [...current, ...accepted]);
    }
  }

  function removeReferenceImage(id) {
    setReferenceImages((current) => {
      const target = current.find((image) => image.id === id);
      if (target) URL.revokeObjectURL(target.previewUrl);
      return current.filter((image) => image.id !== id);
    });
  }

  async function uploadReferencesForJob() {
    if (!referenceImages.length) return [];

    setIsUploadingReferences(true);
    setReferenceUploadError('');
    try {
      const uploadItems = [];
      for (const image of referenceImages) {
        uploadItems.push({
          clientId: `${image.id}:original`,
          imageId: image.id,
          role: 'original',
          file: image.file,
          filename: image.filename,
          mimeType: image.mimeType,
          size: image.size,
        });
      }

      const prepared = await prepareReferenceUploadRequest(
        apiBaseNormalized,
        health,
        uploadItems.map(({ clientId, role, filename, mimeType, size }) => ({ clientId, role, filename, mimeType, size })),
      );
      const uploadMap = new Map((prepared.uploads || []).map((upload) => [upload.clientId, upload]));

      await Promise.all(uploadItems.map(async (item) => {
        const upload = uploadMap.get(item.clientId);
        if (!upload?.uploadUrl) throw new Error('参考图上传地址创建失败。');
        const response = await fetch(upload.uploadUrl, {
          method: 'PUT',
          headers: { 'Content-Type': item.mimeType },
          body: item.file,
        });
        if (!response.ok) throw new Error(`参考图上传失败：HTTP ${response.status}`);
      }));

      const references = [];
      for (const image of referenceImages) {
        const original = uploadMap.get(`${image.id}:original`);
        if (!original) throw new Error('参考图上传结果缺少原图记录。');
        const reference = {
          filename: image.filename,
          mimeType: image.mimeType,
          size: image.size,
          objectKey: original.objectKey,
          uploadToken: original.uploadToken,
        };
        references.push(reference);
      }

      return references;
    } finally {
      setIsUploadingReferences(false);
    }
  }

  async function loadReferenceLibrary(options = {}) {
    if (!options.silent) setReferenceLibraryError('');
    setIsLoadingReferenceLibrary(true);
    try {
      const data = await referenceLibraryRequest(apiBaseNormalized, health, { taskName: isPlotCategory ? 'plot' : 'diagram', limit: 24 });
      if (options.cancelledRef?.()) return;
      setReferenceLibrary(data.references || []);
    } catch (err) {
      if (options.cancelledRef?.()) return;
      setReferenceLibraryError(err.message);
    } finally {
      if (!options.cancelledRef?.()) setIsLoadingReferenceLibrary(false);
    }
  }

  function toggleManualReference(id) {
    setManualReferenceIds((current) => {
      if (current.includes(id)) return current.filter((item) => item !== id);
      if (current.length >= 10) return current;
      return [...current, id];
    });
  }

  function useImageForRefine(url) {
    setRefineSourceUrl(url);
    setRefineInstruction((current) => current || '提升标签可读性，优化留白和箭头关系，保持论文图示风格。');
    setRefineAspectRatio(aspectRatio);
    setActiveTab('refine');
  }

  async function submitJob(event) {
    event.preventDefault();
    setError('');
    setIsSubmitting(true);
    setJob(null);
    latestJobRef.current = null;
    try {
      const uploadedReferenceImages = await uploadReferencesForJob();
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
        taskName: isPlotCategory ? 'plot' : 'diagram',
        methodContent,
        caption,
        infographicCategory: selectedInfographicCategory[1],
        outputFormat,
        mainModelName: isAdvancedMode ? mainModelName : providerConfig.mainModel,
        imageGenModelName: isAdvancedMode ? imageGenModelName : providerConfig.imageModel,
        referenceVisionModelName: isAdvancedMode ? referenceVisionModelName : providerConfig.visionModel,
        referenceImageMode: uploadedReferenceImages.length ? (isAdvancedMode ? referenceImageMode : 'auto') : undefined,
        referenceImages: uploadedReferenceImages,
        pipelineMode: isAdvancedMode ? pipelineMode : 'demo_planner_critic',
        retrievalSetting: isAdvancedMode ? retrievalSetting : 'none',
        manualReferenceIds: isAdvancedMode && retrievalSetting === 'manual' ? manualReferenceIds : [],
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

  async function submitRefine(event) {
    event.preventDefault();
    setRefineError('');
    setIsSubmittingRefine(true);
    setRefineJob(null);
    try {
      const scopedApiKeys = {
        openrouter: '',
        gemini: '',
        openai: '',
        bailian: '',
        [providerConfig.keyName]: selectedKey,
      };
      const created = await refineImageRequest(apiBaseNormalized, health, {
        provider,
        apiKeys: scopedApiKeys,
        mainModelName: isAdvancedMode ? mainModelName : providerConfig.mainModel,
        imageModelName: isAdvancedMode ? imageGenModelName : providerConfig.imageModel,
        sourceImageUrl: refineSourceUrl.trim(),
        editInstruction: refineInstruction,
        aspectRatio: refineAspectRatio,
        imageSize: refineImageSize,
      });
      setRefineJobId(created.id);
      if (currentUser) void loadUserJobs({ silent: true });
    } catch (err) {
      setRefineError(err.message);
    } finally {
      setIsSubmittingRefine(false);
    }
  }

  async function loadAdminOverview(options = {}) {
    if (!isAdmin) return;
    if (!options.silent) {
      setAdminError('');
      setAdminUsersError('');
      setAdminFeedbackError('');
    }
    const [jobsResult, usersResult, feedbackResult] = await Promise.allSettled([
      adminJobsRequest(apiBaseNormalized, health),
      adminUsersRequest(apiBaseNormalized, health),
      adminFeedbackRequest(apiBaseNormalized, health, { limit: 50 }),
    ]);

    if (options.cancelledRef?.()) return;

    if (jobsResult.status === 'fulfilled') {
      setAdminJobs(jobsResult.value.jobs || []);
    } else {
      setAdminError(jobsResult.reason?.message || String(jobsResult.reason));
    }

    if (usersResult.status === 'fulfilled') {
      setAdminUsers(usersResult.value.users || []);
    } else {
      setAdminUsersError(usersResult.reason?.message || String(usersResult.reason));
    }

    if (feedbackResult.status === 'fulfilled') {
      setAdminFeedback(feedbackResult.value.feedback || []);
    } else {
      setAdminFeedbackError(feedbackResult.reason?.message || String(feedbackResult.reason));
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
    setIsAdmin(false);
    setActiveTab('generate');
    setCurrentJobId('');
    setJob(null);
    setUserJobs([]);
  }

  function openFeedbackDialog() {
    setFeedbackError('');
    setFeedbackSuccess(false);
    setShowFeedbackDialog(true);
  }

  function closeFeedbackDialog() {
    setShowFeedbackDialog(false);
    setFeedbackError('');
    setFeedbackSuccess(false);
  }

  async function handleSubmitFeedback(payload) {
    setFeedbackError('');
    setFeedbackSuccess(false);
    setIsSubmittingFeedback(true);
    try {
      await submitFeedbackRequest(apiBaseNormalized, health, {
        message: payload.message,
        category: payload.category,
        contact: payload.contact,
        platform: 'web',
        clientVersion: CLIENT_VERSION,
        jobId: currentJobId || latestJobRef.current?.id || '',
      });
      setFeedbackSuccess(true);
      return true;
    } catch (err) {
      setFeedbackError(err.message);
      return false;
    } finally {
      setIsSubmittingFeedback(false);
    }
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

      <FeedbackDialog
        open={showFeedbackDialog}
        isSubmitting={isSubmittingFeedback}
        error={feedbackError}
        success={feedbackSuccess}
        onClose={closeFeedbackDialog}
        onSubmit={handleSubmitFeedback}
      />

      <button type="button" className="feedback-fab" onClick={openFeedbackDialog}>
        <MessageSquare size={18} />
        <span>意见反馈</span>
      </button>

      <nav className="paper-tabs">
        <button type="button" className={activeTab === 'generate' ? 'active' : ''} onClick={() => setActiveTab('generate')}>生成候选图</button>
        <button type="button" className={activeTab === 'refine' ? 'active' : ''} onClick={() => setActiveTab('refine')}>精修图片</button>
        <button type="button" className={activeTab === 'records' ? 'active' : ''} onClick={() => setActiveTab('records')}>任务记录</button>
        {isAdmin ? (
          <button type="button" className={activeTab === 'admin' ? 'active' : ''} onClick={() => setActiveTab('admin')}>站长</button>
        ) : null}
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

          <div className="output-format-field">
            <Select label="导出格式" value={outputFormat} onChange={setOutputFormat} options={OUTPUT_FORMATS} />
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
              <span>{defaultVisionModelLabel}</span>
              <span>规划器 + 评审器</span>
              <span>16:9</span>
              <span>{formatOutputFormat(outputFormat)}</span>
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
                  {/* max 与后端 PAPERBANANA_MAX_CANDIDATES 默认值 (3) 对齐，避免用户选到被后端静默 clamp 的值。 */}
                  <input type="number" min="1" max="3" value={numCandidates} onChange={(event) => setNumCandidates(event.target.value)} />
                </label>
                <label className="field compact">
                  <span>评审轮数</span>
                  <input type="number" min="0" max="3" value={maxCriticRounds} onChange={(event) => setMaxCriticRounds(event.target.value)} />
                </label>
              </div>

              <div className="model-grid">
                <Select label="主模型" value={mainModelName} onChange={setMainModelName} options={providerConfig.mainModels} />
                <Select label="图像生成模型" value={imageGenModelName} onChange={setImageGenModelName} options={providerConfig.imageModels} />
                {referenceImages.length && referenceImageMode === 'main_model' ? null : (
                  <Select label="参考图识别模型" value={referenceVisionModelName} onChange={setReferenceVisionModelName} options={providerConfig.visionModels || []} />
                )}
              </div>

              {referenceImages.length ? (
                <div className="reference-mode-panel">
                  <span>参考图处理方式</span>
                  <div className="reference-mode-switch">
                    {REFERENCE_IMAGE_MODES.map(([id, label]) => (
                      <button
                        type="button"
                        key={id}
                        className={referenceImageMode === id ? 'active' : ''}
                        disabled={id === 'main_model' && !canSelectMainModelDirect}
                        onClick={() => setReferenceImageMode(id)}
                      >
                        {label}
                      </button>
                    ))}
                  </div>
                  {referenceCapabilityNote ? <p>{referenceCapabilityNote}</p> : null}
                </div>
              ) : null}

              {health?.mock_enabled ? (
                <label className="mock-switch">
                  <input type="checkbox" checked={mock} onChange={(event) => setMock(event.target.checked)} />
                  <span>模拟模式</span>
                </label>
              ) : null}

              {retrievalSetting === 'manual' ? (
                <ReferenceLibraryPanel
                  references={referenceLibrary}
                  selectedIds={manualReferenceIds}
                  isLoading={isLoadingReferenceLibrary}
                  error={referenceLibraryError}
                  onToggle={toggleManualReference}
                  onRefresh={() => loadReferenceLibrary()}
                />
              ) : null}
            </>
          )}

          <button className="primary-button" type="submit" disabled={!canSubmit}>
            {isSubmitting ? <Loader2 className="spin" size={18} /> : <Send size={18} />}
            {isUploadingReferences ? '上传参考图' : '生成候选图'}
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
          {isPlotCategory ? (
            <div className="plot-note">
              统计图由独立渲染服务生成，可能稍慢。
            </div>
          ) : null}

          <ReferenceUploadPanel
            images={referenceImages}
            error={referenceUploadError}
            disabled={isSubmitting}
            isUploading={isUploadingReferences}
            onAddFiles={addReferenceFiles}
            onRemove={removeReferenceImage}
          />

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
          <JobStatus job={job} apiBase={apiBaseNormalized} onUseForRefine={useImageForRefine} />
        </section>
        </section>
      ) : activeTab === 'refine' ? (
        <RefinePanel
          sourceUrl={refineSourceUrl}
          instruction={refineInstruction}
          imageSize={refineImageSize}
          aspectRatio={refineAspectRatio}
          canSubmit={canSubmitRefine}
          isSubmitting={isSubmittingRefine}
          error={refineError}
          job={refineJob}
          apiBase={apiBaseNormalized}
          onSourceUrlChange={setRefineSourceUrl}
          onInstructionChange={setRefineInstruction}
          onImageSizeChange={setRefineImageSize}
          onAspectRatioChange={setRefineAspectRatio}
          onSubmit={submitRefine}
        />
      ) : activeTab === 'admin' && isAdmin ? (
        <section className="admin-panel">
          <div className="section-head">
            <Eye size={20} />
            <div>
              <h2>站长观察面板</h2>
              <p>已通过登录账号识别管理员身份，可查看账号、反馈和最近任务。</p>
            </div>
          </div>
          <div className="admin-controls admin-controls-single">
            <button type="button" onClick={() => loadAdminOverview()}><RefreshCcw size={17} />刷新</button>
          </div>
          <div className="admin-section">
            <div className="admin-section-title">
              <Users size={17} />
              <strong>账号记录</strong>
              <span>{adminUsers.length ? `${adminUsers.length} 个账号` : '注册/登录后会出现在这里'}</span>
            </div>
            {adminUsersError ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(adminUsersError)}</div> : null}
            <AdminUsersTable users={adminUsers} />
          </div>
          <div className="admin-section">
            <div className="admin-section-title">
              <MessageSquare size={17} />
              <strong>用户反馈</strong>
              <span>{adminFeedback.length ? `${adminFeedback.length} 条反馈` : '暂无反馈数据'}</span>
            </div>
            {adminFeedbackError ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(adminFeedbackError)}</div> : null}
            <AdminFeedbackTable feedback={adminFeedback} />
          </div>
          <div className="admin-section">
            <div className="admin-section-title">
              <FileText size={17} />
              <strong>最近任务</strong>
              <span>{adminJobs.length ? `${adminJobs.length} 条任务` : '暂无任务数据'}</span>
            </div>
            {adminError ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(adminError)}</div> : null}
            <JobTable jobs={adminJobs} showUser apiBase={apiBaseNormalized} onUseForRefine={useImageForRefine} />
          </div>
        </section>
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
          onUseForRefine={useImageForRefine}
        />
      )}
        </>
      )}
    </main>
  );
}

function normalizeReferenceMimeType(file) {
  const mimeType = (file.type || '').toLowerCase();
  if (mimeType === 'image/jpg') return 'image/jpeg';
  if (mimeType) return mimeType;
  const name = (file.name || '').toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.svg')) return 'image/svg+xml';
  return '';
}

function extensionForMimeType(mimeType) {
  if (mimeType === 'image/png') return 'png';
  if (mimeType === 'image/jpeg') return 'jpg';
  if (mimeType === 'image/webp') return 'webp';
  if (mimeType === 'image/svg+xml') return 'svg';
  return 'png';
}

function findModelLabel(options, value) {
  const option = options.find(([id]) => id === value);
  return option ? option[1] : value;
}

function describeReferenceCapability(capability) {
  if (!capability || capability.status === 'loading') return '正在检查当前主模型是否支持直接理解参考图。';
  if (capability.status === 'supported') return '当前主模型支持直接理解参考图，可使用主模型直读。';
  if (capability.status === 'unsupported') return '当前主模型不支持直接理解参考图，请使用独立识别模型或更换主模型。';
  return '当前主模型的参考图能力无法确认；可以尝试主模型直读，失败时请改用独立识别模型或更换主模型。';
}
