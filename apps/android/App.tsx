import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  KeyboardAvoidingView,
  Linking,
  Modal,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import {
  AlertTriangle,
  Eye,
  FileText,
  Image as ImageIcon,
  KeyRound,
  Loader2,
  LogIn,
  RefreshCw,
  Send,
  Settings2,
  ShieldCheck,
  Sparkles,
  UserRound,
  X,
} from 'lucide-react-native';

import {
  adminJobsRequest,
  createJobRequest,
  fetchBackendHealth,
  formatDate,
  formatErrorMessage,
  getJobRequest,
  getSession,
  normalizeApiBase,
  resolveImageUrl,
  signInEmail,
  signOut,
  signUpEmail,
  userJobsRequest,
} from './src/api';
import {
  API_BASE_DEFAULT,
  ASPECT_RATIO_OPTIONS,
  INFOGRAPHIC_CATEGORIES,
  PIPELINE_OPTIONS,
  PROVIDER_ORDER,
  PROVIDERS,
  QUICK_START_EXAMPLES,
  RETRIEVAL_OPTIONS,
  STATUS_LABELS,
} from './src/constants';
import type { AuthMode, ConfigurationMode, CurrentUser, HealthInfo, Job, ProviderId, QuickStartExample } from './src/types';

const EMPTY_KEYS: Record<ProviderId, string> = {
  bailian: '',
  openrouter: '',
  gemini: '',
  openai: '',
};

const DEFAULT_CATEGORY = INFOGRAPHIC_CATEGORIES[0]!;
const DEFAULT_PROVIDER = PROVIDERS.bailian;

type TabId = 'generate' | 'records' | 'admin';

export default function App() {
  const [activeTab, setActiveTab] = useState<TabId>('generate');
  const [apiBase, setApiBase] = useState(API_BASE_DEFAULT);
  const [health, setHealth] = useState<HealthInfo | null>(null);
  const [healthError, setHealthError] = useState('');
  const [healthLoading, setHealthLoading] = useState(false);

  const [currentUser, setCurrentUser] = useState<CurrentUser | null>(null);
  const [sessionPending, setSessionPending] = useState(true);
  const [showAuthPanel, setShowAuthPanel] = useState(false);
  const [authMode, setAuthMode] = useState<AuthMode>('sign-in');
  const [authEmail, setAuthEmail] = useState('');
  const [authPassword, setAuthPassword] = useState('');
  const [authName, setAuthName] = useState('');
  const [authError, setAuthError] = useState('');
  const [authSubmitting, setAuthSubmitting] = useState(false);

  const [configurationMode, setConfigurationMode] = useState<ConfigurationMode>('simple');
  const [provider, setProvider] = useState<ProviderId>('bailian');
  const [apiKeys, setApiKeys] = useState<Record<ProviderId, string>>(EMPTY_KEYS);
  const [methodContent, setMethodContent] = useState(QUICK_START_EXAMPLES[0]?.methodContent || '');
  const [caption, setCaption] = useState(QUICK_START_EXAMPLES[0]?.caption || '');
  const [infographicCategory, setInfographicCategory] = useState<string>(DEFAULT_CATEGORY[0]);
  const [mainModelName, setMainModelName] = useState(DEFAULT_PROVIDER.mainModel);
  const [imageGenModelName, setImageGenModelName] = useState(DEFAULT_PROVIDER.imageModel);
  const [pipelineMode, setPipelineMode] = useState('demo_planner_critic');
  const [retrievalSetting, setRetrievalSetting] = useState('none');
  const [aspectRatio, setAspectRatio] = useState('16:9');
  const [numCandidates, setNumCandidates] = useState('1');
  const [maxCriticRounds, setMaxCriticRounds] = useState('1');
  const [mock, setMock] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState('');
  const [currentJobId, setCurrentJobId] = useState('');
  const [job, setJob] = useState<Job | null>(null);

  const [userJobs, setUserJobs] = useState<Job[]>([]);
  const [userJobsLoading, setUserJobsLoading] = useState(false);
  const [userJobsError, setUserJobsError] = useState('');

  const [adminToken, setAdminToken] = useState('');
  const [adminJobs, setAdminJobs] = useState<Job[]>([]);
  const [adminLoading, setAdminLoading] = useState(false);
  const [adminError, setAdminError] = useState('');
  const [previewUrl, setPreviewUrl] = useState('');

  const apiBaseNormalized = normalizeApiBase(apiBase);
  const providerConfig = PROVIDERS[provider] || DEFAULT_PROVIDER;
  const selectedKey = apiKeys[providerConfig.keyName] || '';
  const selectedCategory = INFOGRAPHIC_CATEGORIES.find((item) => item[0] === infographicCategory) || DEFAULT_CATEGORY;
  const isAdvancedMode = configurationMode === 'advanced';
  const mockEnabled = Boolean(health?.mock_enabled || health?.laf?.mock_enabled);

  const canSubmit = useMemo(() => {
    const canMock = isAdvancedMode && mock && mockEnabled;
    return Boolean(
      !isSubmitting &&
        methodContent.trim().length >= 20 &&
        caption.trim().length >= 3 &&
        (selectedKey.trim() || canMock),
    );
  }, [caption, isAdvancedMode, isSubmitting, methodContent, mock, mockEnabled, selectedKey]);

  useEffect(() => {
    void refreshHealth();
  }, [apiBaseNormalized]);

  useEffect(() => {
    void refreshSession();
  }, [apiBaseNormalized]);

  useEffect(() => {
    if (!currentUser) return;
    void loadUserJobs(true);
  }, [apiBaseNormalized, currentUser?.id, health?.backendMode]);

  useEffect(() => {
    if (!currentJobId) return undefined;
    let cancelled = false;
    const load = async () => {
      try {
        const nextJob = await getJobRequest(apiBaseNormalized, health, currentJobId);
        if (!cancelled) setJob(nextJob);
      } catch (error) {
        if (!cancelled) setSubmitError(formatErrorMessage(error));
      }
    };
    void load();
    const timer = setInterval(load, 3000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [apiBaseNormalized, currentJobId, health?.backendMode]);

  function updateProvider(nextProvider: ProviderId) {
    const nextConfig = PROVIDERS[nextProvider] || DEFAULT_PROVIDER;
    setProvider(nextProvider);
    setMainModelName(nextConfig.mainModel);
    setImageGenModelName(nextConfig.imageModel);
  }

  async function refreshHealth() {
    setHealthLoading(true);
    setHealthError('');
    try {
      const data = await fetchBackendHealth(apiBaseNormalized);
      setHealth(data);
    } catch (error) {
      setHealth(null);
      setHealthError(formatErrorMessage(error));
    } finally {
      setHealthLoading(false);
    }
  }

  async function refreshSession() {
    setSessionPending(true);
    try {
      const user = await getSession(apiBaseNormalized);
      setCurrentUser(user);
    } finally {
      setSessionPending(false);
    }
  }

  async function submitAuth() {
    if (!authEmail.trim() || authPassword.length < 8 || authSubmitting) return;
    setAuthSubmitting(true);
    setAuthError('');
    try {
      if (authMode === 'sign-up') {
        await signUpEmail(apiBaseNormalized, authEmail.trim(), authPassword, authName.trim() || authEmail.trim().split('@')[0] || 'PaperBanana 用户');
      } else {
        await signInEmail(apiBaseNormalized, authEmail.trim(), authPassword);
      }
      const user = await getSession(apiBaseNormalized);
      setCurrentUser(user);
      setShowAuthPanel(false);
      setAuthPassword('');
      setActiveTab('records');
      if (user) await loadUserJobs(false);
    } catch (error) {
      setAuthError(formatErrorMessage(error));
    } finally {
      setAuthSubmitting(false);
    }
  }

  async function handleSignOut() {
    await signOut(apiBaseNormalized);
    setCurrentUser(null);
    setUserJobs([]);
    setShowAuthPanel(false);
  }

  async function submitJob() {
    if (!canSubmit || isSubmitting) return;
    setIsSubmitting(true);
    setSubmitError('');
    setJob(null);
    try {
      const scopedApiKeys = {
        ...EMPTY_KEYS,
        [providerConfig.keyName]: selectedKey.trim(),
      };
      const created = await createJobRequest(apiBaseNormalized, health, {
        configurationMode,
        provider,
        apiKeys: scopedApiKeys,
        taskName: 'diagram',
        methodContent: methodContent.trim(),
        caption: caption.trim(),
        infographicCategory: selectedCategory[1],
        mainModelName: isAdvancedMode ? mainModelName.trim() : providerConfig.mainModel,
        imageGenModelName: isAdvancedMode ? imageGenModelName.trim() : providerConfig.imageModel,
        pipelineMode: isAdvancedMode ? pipelineMode : 'demo_planner_critic',
        retrievalSetting: isAdvancedMode ? retrievalSetting : 'none',
        aspectRatio: isAdvancedMode ? aspectRatio : '16:9',
        numCandidates: isAdvancedMode ? clampNumber(numCandidates, 1, 4, 1) : 1,
        maxCriticRounds: isAdvancedMode ? clampNumber(maxCriticRounds, 0, 3, 1) : 1,
        mock: isAdvancedMode ? mock : false,
      });
      if (!created.id) throw new Error('后端没有返回任务 ID');
      setCurrentJobId(created.id);
      setJob({
        id: created.id,
        status: created.status,
        provider,
        user_id: currentUser?.id || '',
        user_email: currentUser?.email || '',
        configuration_mode: configurationMode,
        method_content: methodContent.trim(),
        caption: caption.trim(),
        infographic_category: selectedCategory[1],
        main_model_name: isAdvancedMode ? mainModelName.trim() : providerConfig.mainModel,
        image_gen_model_name: isAdvancedMode ? imageGenModelName.trim() : providerConfig.imageModel,
        pipeline_mode: isAdvancedMode ? pipelineMode : 'demo_planner_critic',
        aspect_ratio: isAdvancedMode ? aspectRatio : '16:9',
        num_candidates: isAdvancedMode ? clampNumber(numCandidates, 1, 4, 1) : 1,
        max_critic_rounds: isAdvancedMode ? clampNumber(maxCriticRounds, 0, 3, 1) : 1,
        prompt_char_count: 0,
        result_image_count: 0,
        result_images: [],
        logs_tail: '',
        error: '',
      });
      if (currentUser) void loadUserJobs(true);
    } catch (error) {
      setSubmitError(formatErrorMessage(error));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function loadUserJobs(silent: boolean) {
    if (!currentUser) return;
    if (!silent) {
      setUserJobsLoading(true);
      setUserJobsError('');
    }
    try {
      const data = await userJobsRequest(apiBaseNormalized, health);
      setUserJobs(data.jobs || []);
    } catch (error) {
      setUserJobsError(formatErrorMessage(error));
    } finally {
      setUserJobsLoading(false);
    }
  }

  async function loadAdminJobs() {
    setAdminLoading(true);
    setAdminError('');
    try {
      const data = await adminJobsRequest(apiBaseNormalized, health, adminToken.trim());
      setAdminJobs(data.jobs || []);
    } catch (error) {
      setAdminError(formatErrorMessage(error));
    } finally {
      setAdminLoading(false);
    }
  }

  function applyQuickStartExample(example: QuickStartExample) {
    setMethodContent(example.methodContent);
    setCaption(example.caption);
    setInfographicCategory(example.category);
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="dark" />
      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.header}>
          <View style={styles.brandRow}>
            <Image source={require('./assets/icon.png')} style={styles.logo} />
            <View style={styles.brandText}>
              <Text style={styles.title}>PaperBanana 工作台</Text>
              <Text style={styles.subtitle}>多智能体学术图示生成</Text>
            </View>
          </View>
          {currentUser ? (
            <Pressable style={styles.accountPill} onPress={handleSignOut}>
              <ShieldCheck size={15} color="#20766e" />
              <Text style={styles.accountText} numberOfLines={1}>
                {currentUser.email}
              </Text>
            </Pressable>
          ) : (
            <Pressable style={styles.loginPill} onPress={() => setShowAuthPanel(true)}>
              <LogIn size={15} color="#1b1a16" />
              <Text style={styles.loginText}>登录</Text>
            </Pressable>
          )}
        </View>

        <View style={styles.tabs}>
          <TabButton label="生成" active={activeTab === 'generate'} onPress={() => setActiveTab('generate')} />
          <TabButton label="记录" active={activeTab === 'records'} onPress={() => setActiveTab('records')} />
          <TabButton label="管理" active={activeTab === 'admin'} onPress={() => setActiveTab('admin')} />
        </View>

        <ScrollView style={styles.scroll} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          {activeTab === 'generate' ? renderGenerate() : null}
          {activeTab === 'records' ? renderRecords() : null}
          {activeTab === 'admin' ? renderAdmin() : null}
        </ScrollView>
      </KeyboardAvoidingView>

      <AuthModal
        visible={showAuthPanel}
        mode={authMode}
        email={authEmail}
        password={authPassword}
        name={authName}
        error={authError}
        submitting={authSubmitting}
        onClose={() => setShowAuthPanel(false)}
        onModeChange={setAuthMode}
        onEmailChange={setAuthEmail}
        onPasswordChange={setAuthPassword}
        onNameChange={setAuthName}
        onSubmit={submitAuth}
      />

      <Modal visible={Boolean(previewUrl)} transparent animationType="fade" onRequestClose={() => setPreviewUrl('')}>
        <View style={styles.previewBackdrop}>
          <Pressable style={styles.previewClose} onPress={() => setPreviewUrl('')}>
            <X size={22} color="#fff" />
          </Pressable>
          {previewUrl ? <Image source={{ uri: previewUrl }} resizeMode="contain" style={styles.previewImage} /> : null}
        </View>
      </Modal>
    </SafeAreaView>
  );

  function renderGenerate() {
    return (
      <>
        <HealthBanner loading={healthLoading} health={health} error={healthError} onRefresh={refreshHealth} />

        <SectionHeader icon={<Settings2 size={19} color="#20766e" />} title="生成设置" note={isAdvancedMode ? '模型、流程和渲染参数全部开放。' : '选择模型平台并填写当前平台 API Key。'} />

        <View style={styles.modeSwitch}>
          <ModeButton active={!isAdvancedMode} title="普通模式" subtitle="平台 + Key" icon={<Sparkles size={16} color={!isAdvancedMode ? '#fff' : '#20766e'} />} onPress={() => setConfigurationMode('simple')} />
          <ModeButton active={isAdvancedMode} title="专业模式" subtitle="模型与流程" icon={<Settings2 size={16} color={isAdvancedMode ? '#fff' : '#20766e'} />} onPress={() => setConfigurationMode('advanced')} />
        </View>

        <Text style={styles.fieldLabel}>模型平台</Text>
        <View style={styles.providerGrid}>
          {PROVIDER_ORDER.map((id) => (
            <Chip key={id} label={PROVIDERS[id].label} active={provider === id} onPress={() => updateProvider(id)} />
          ))}
        </View>

        <View style={styles.panel}>
          <View style={styles.panelTitleRow}>
            <KeyRound size={17} color="#20766e" />
            <Text style={styles.panelTitle}>{providerConfig.label} API 密钥</Text>
          </View>
          <TextInput
            style={styles.input}
            value={selectedKey}
            secureTextEntry
            autoCapitalize="none"
            placeholder={providerConfig.keyPlaceholder}
            placeholderTextColor="#9b9488"
            onChangeText={(value) => setApiKeys((prev) => ({ ...prev, [providerConfig.keyName]: value }))}
          />
          <Pressable onPress={() => Linking.openURL(providerConfig.guideUrl)} style={styles.guideLink}>
            <Text style={styles.guideLinkText}>打开申请页面</Text>
          </Pressable>
          {providerConfig.guideSteps.map((step, index) => (
            <Text key={step} style={styles.guideStep}>
              {index + 1}. {step}
            </Text>
          ))}
        </View>

        {!isAdvancedMode ? (
          <View style={styles.summaryRow}>
            <SummaryPill label={providerConfig.mainModel} />
            <SummaryPill label={providerConfig.imageModel} />
            <SummaryPill label="规划器 + 评审器" />
            <SummaryPill label="16:9" />
          </View>
        ) : (
          <View style={styles.advancedBlock}>
            <LabeledInput label="后端地址" value={apiBase} onChangeText={setApiBase} autoCapitalize="none" />
            <OptionGroup title="生成流程" value={pipelineMode} options={PIPELINE_OPTIONS} onChange={setPipelineMode} />
            <OptionGroup title="检索设置" value={retrievalSetting} options={RETRIEVAL_OPTIONS} onChange={setRetrievalSetting} />
            <OptionGroup title="画面比例" value={aspectRatio} options={ASPECT_RATIO_OPTIONS} onChange={setAspectRatio} />
            <View style={styles.inlineInputs}>
              <LabeledInput label="候选图数量" value={numCandidates} onChangeText={setNumCandidates} keyboardType="number-pad" compact />
              <LabeledInput label="评审轮数" value={maxCriticRounds} onChangeText={setMaxCriticRounds} keyboardType="number-pad" compact />
            </View>
            <LabeledInput label="主模型名称" value={mainModelName} onChangeText={setMainModelName} autoCapitalize="none" />
            <LabeledInput label="图像生成模型" value={imageGenModelName} onChangeText={setImageGenModelName} autoCapitalize="none" />
            {mockEnabled ? (
              <View style={styles.switchRow}>
                <Text style={styles.switchText}>模拟模式</Text>
                <Switch value={mock} onValueChange={setMock} thumbColor={mock ? '#20766e' : '#f4f0e8'} trackColor={{ false: '#d7d1c5', true: '#9fc8bd' }} />
              </View>
            ) : null}
          </View>
        )}

        <SectionHeader icon={<FileText size={19} color="#20766e" />} title="输入内容" note="选择信息图类别，再粘贴论文方法部分和目标图注。" />

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.exampleRow}>
          {QUICK_START_EXAMPLES.map((example) => (
            <Pressable key={example.id} style={styles.exampleCard} onPress={() => applyQuickStartExample(example)}>
              <Text style={styles.exampleLabel}>{example.label}</Text>
              <Text style={styles.exampleTitle}>{example.title}</Text>
              <Text style={styles.exampleCaption} numberOfLines={2}>
                {example.caption}
              </Text>
              <Text style={styles.exampleHint} numberOfLines={2}>
                {example.hint}
              </Text>
            </Pressable>
          ))}
        </ScrollView>

        <OptionGroup title="信息图类别" value={infographicCategory} options={INFOGRAPHIC_CATEGORIES.map((item) => [item[0], item[1]] as const)} onChange={setInfographicCategory} />
        <Text style={styles.categoryNote}>{selectedCategory[2]}</Text>

        <LabeledInput label="论文方法内容" value={methodContent} onChangeText={setMethodContent} multiline minHeight={168} />
        <LabeledInput label="目标图注" value={caption} onChangeText={setCaption} multiline minHeight={92} />

        <Pressable style={[styles.primaryButton, !canSubmit && styles.disabledButton]} disabled={!canSubmit} onPress={submitJob}>
          {isSubmitting ? <ActivityIndicator color="#fff" /> : <Send size={18} color="#fff" />}
          <Text style={styles.primaryButtonText}>{isSubmitting ? '提交中' : '生成候选图'}</Text>
        </Pressable>
        {submitError ? <ErrorLine text={submitError} /> : null}

        <SectionHeader icon={<ImageIcon size={19} color="#20766e" />} title="生成结果" note={currentJobId ? `任务编号 ${currentJobId}` : '提交任务后显示生成结果。'} />
        <JobDetail job={job} apiBase={apiBaseNormalized} onPreview={setPreviewUrl} />
      </>
    );
  }

  function renderRecords() {
    if (sessionPending) {
      return <StatePanel icon={<Loader2 size={20} color="#20766e" />} title="正在检查登录状态" note="请稍候。" />;
    }
    if (!currentUser) {
      return (
        <StatePanel
          icon={<UserRound size={20} color="#20766e" />}
          title="任务记录需要登录后使用"
          note="不登录也可以正常生成候选图；登录后，新提交的任务会保存到账号记录。"
          actionLabel="登录 / 注册"
          onAction={() => setShowAuthPanel(true)}
        />
      );
    }
    return (
      <>
        <SectionHeader icon={<FileText size={19} color="#20766e" />} title="我的任务记录" note={currentUser.email} />
        <Pressable style={styles.secondaryButton} onPress={() => loadUserJobs(false)}>
          {userJobsLoading ? <ActivityIndicator color="#20766e" /> : <RefreshCw size={17} color="#20766e" />}
          <Text style={styles.secondaryButtonText}>刷新任务记录</Text>
        </Pressable>
        {userJobsError ? <ErrorLine text={userJobsError} /> : null}
        <JobList jobs={userJobs} apiBase={apiBaseNormalized} emptyText="暂无任务记录" onPreview={setPreviewUrl} />
      </>
    );
  }

  function renderAdmin() {
    return (
      <>
        <SectionHeader icon={<Eye size={19} color="#20766e" />} title="站长观察面板" note="输入 ADMIN_TOKEN 查看最近任务、模型选择和失败原因。" />
        <LabeledInput label="ADMIN_TOKEN" value={adminToken} secureTextEntry onChangeText={setAdminToken} autoCapitalize="none" />
        <Pressable style={styles.secondaryButton} onPress={loadAdminJobs}>
          {adminLoading ? <ActivityIndicator color="#20766e" /> : <RefreshCw size={17} color="#20766e" />}
          <Text style={styles.secondaryButtonText}>刷新最近任务</Text>
        </Pressable>
        {adminError ? <ErrorLine text={adminError} /> : null}
        <JobList jobs={adminJobs} apiBase={apiBaseNormalized} showUser emptyText="暂无任务记录" onPreview={setPreviewUrl} />
      </>
    );
  }
}

function TabButton({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.tabButton, active && styles.tabButtonActive]} onPress={onPress}>
      <Text style={[styles.tabText, active && styles.tabTextActive]}>{label}</Text>
    </Pressable>
  );
}

function ModeButton({ active, title, subtitle, icon, onPress }: { active: boolean; title: string; subtitle: string; icon: React.ReactNode; onPress: () => void }) {
  return (
    <Pressable style={[styles.modeButton, active && styles.modeButtonActive]} onPress={onPress}>
      {icon}
      <View>
        <Text style={[styles.modeTitle, active && styles.modeTitleActive]}>{title}</Text>
        <Text style={[styles.modeSubtitle, active && styles.modeSubtitleActive]}>{subtitle}</Text>
      </View>
    </Pressable>
  );
}

function Chip({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable style={[styles.chip, active && styles.chipActive]} onPress={onPress}>
      <Text style={[styles.chipText, active && styles.chipTextActive]}>{label}</Text>
    </Pressable>
  );
}

function SectionHeader({ icon, title, note }: { icon: React.ReactNode; title: string; note: string }) {
  return (
    <View style={styles.sectionHeader}>
      {icon}
      <View style={styles.sectionCopy}>
        <Text style={styles.sectionTitle}>{title}</Text>
        <Text style={styles.sectionNote}>{note}</Text>
      </View>
    </View>
  );
}

function HealthBanner({ loading, health, error, onRefresh }: { loading: boolean; health: HealthInfo | null; error: string; onRefresh: () => void }) {
  const ok = Boolean(health);
  return (
    <View style={[styles.healthBanner, ok ? styles.healthOk : styles.healthWarn]}>
      <View style={styles.healthTextBlock}>
        <Text style={styles.healthTitle}>{ok ? `后端可用 · ${health?.backendMode || 'auto'}` : '后端未确认'}</Text>
        <Text style={styles.healthNote}>{ok ? '生成、登录和任务记录会使用当前后端地址。' : error || '正在检测后端连接。'}</Text>
      </View>
      <Pressable style={styles.refreshIconButton} onPress={onRefresh}>
        {loading ? <ActivityIndicator color="#20766e" /> : <RefreshCw size={18} color="#20766e" />}
      </Pressable>
    </View>
  );
}

function LabeledInput({
  label,
  value,
  onChangeText,
  multiline,
  minHeight,
  compact,
  secureTextEntry,
  autoCapitalize,
  keyboardType,
}: {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
  multiline?: boolean;
  minHeight?: number;
  compact?: boolean;
  secureTextEntry?: boolean;
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
  keyboardType?: 'default' | 'number-pad';
}) {
  return (
    <View style={[styles.field, compact && styles.compactField]}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        style={[styles.input, multiline && styles.textarea, minHeight ? { minHeight } : null]}
        value={value}
        onChangeText={onChangeText}
        multiline={multiline}
        textAlignVertical={multiline ? 'top' : 'center'}
        secureTextEntry={secureTextEntry}
        autoCapitalize={autoCapitalize}
        keyboardType={keyboardType}
        placeholderTextColor="#9b9488"
      />
    </View>
  );
}

function OptionGroup<T extends string>({
  title,
  value,
  options,
  onChange,
}: {
  title: string;
  value: T | string;
  options: ReadonlyArray<readonly [string, string]>;
  onChange: (value: T) => void;
}) {
  return (
    <View style={styles.optionGroup}>
      <Text style={styles.fieldLabel}>{title}</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.optionRow}>
        {options.map(([id, label]) => (
          <Chip key={id} label={label} active={value === id} onPress={() => onChange(id as T)} />
        ))}
      </ScrollView>
    </View>
  );
}

function SummaryPill({ label }: { label: string }) {
  return (
    <View style={styles.summaryPill}>
      <Text style={styles.summaryText} numberOfLines={1}>
        {label}
      </Text>
    </View>
  );
}

function ErrorLine({ text }: { text: string }) {
  return (
    <View style={styles.errorLine}>
      <AlertTriangle size={16} color="#b4442f" />
      <Text style={styles.errorText}>{text}</Text>
    </View>
  );
}

function StatePanel({ icon, title, note, actionLabel, onAction }: { icon: React.ReactNode; title: string; note: string; actionLabel?: string; onAction?: () => void }) {
  return (
    <View style={styles.statePanel}>
      {icon}
      <Text style={styles.stateTitle}>{title}</Text>
      <Text style={styles.stateNote}>{note}</Text>
      {actionLabel && onAction ? (
        <Pressable style={styles.primaryButton} onPress={onAction}>
          <Text style={styles.primaryButtonText}>{actionLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function JobDetail({ job, apiBase, onPreview }: { job: Job | null; apiBase: string; onPreview: (url: string) => void }) {
  if (!job) return <View style={styles.emptyBox}><Text style={styles.emptyTitle}>暂无生成任务</Text><Text style={styles.emptyNote}>提交后会显示实时状态和候选图。</Text></View>;
  const images = job.result_images.filter((image) => image.url);
  return (
    <View style={styles.jobCard}>
      <View style={styles.jobTopline}>
        <StatusBadge status={job.status} />
        <Text style={styles.jobId} numberOfLines={1}>{job.id}</Text>
      </View>
      <Text style={styles.jobCaption}>{job.caption || '未记录图注'}</Text>
      <View style={styles.jobMetaRow}>
        <Text style={styles.jobMeta}>{job.infographic_category || '方法框架图'}</Text>
        <Text style={styles.jobMeta}>{job.provider || '模型服务'}</Text>
        <Text style={styles.jobMeta}>{formatConfigurationMode(job.configuration_mode)}</Text>
      </View>
      {job.error ? <ErrorLine text={formatErrorMessage(job.error)} /> : null}
      {images.length ? <ImageGrid images={images} apiBase={apiBase} onPreview={onPreview} /> : <Text style={styles.emptyNote}>任务完成后会在这里显示候选图。</Text>}
    </View>
  );
}

function JobList({ jobs, apiBase, showUser, emptyText, onPreview }: { jobs: Job[]; apiBase: string; showUser?: boolean; emptyText: string; onPreview: (url: string) => void }) {
  if (!jobs.length) {
    return (
      <View style={styles.emptyBox}>
        <Text style={styles.emptyTitle}>{emptyText}</Text>
        <Text style={styles.emptyNote}>新任务完成后会出现在这里。</Text>
      </View>
    );
  }
  return (
    <View style={styles.jobList}>
      {jobs.map((item) => {
        const images = item.result_images.filter((image) => image.url);
        return (
          <View style={styles.jobCard} key={item.id}>
            <View style={styles.jobTopline}>
              <StatusBadge status={item.status} />
              <Text style={styles.jobDate}>{formatDate(item.created_at)}</Text>
            </View>
            <Text style={styles.jobCaption}>{item.caption || '未记录图注'}</Text>
            <View style={styles.jobMetaRow}>
              <Text style={styles.jobMeta}>{item.infographic_category || '方法框架图'}</Text>
              <Text style={styles.jobMeta}>{item.provider || '模型服务'}</Text>
              <Text style={styles.jobMeta}>{formatConfigurationMode(item.configuration_mode)}</Text>
            </View>
            {showUser ? <Text style={styles.userEmail}>{item.user_email || '匿名用户'}</Text> : null}
            <View style={styles.modelsBlock}>
              <Text style={styles.modelText}>主模型：{item.main_model_name || '未记录'}</Text>
              <Text style={styles.modelText}>图像模型：{item.image_gen_model_name || '未记录'}</Text>
            </View>
            {item.method_content ? <Text style={styles.methodPreview} numberOfLines={3}>{item.method_content}</Text> : null}
            {images.length ? <ImageGrid images={images} apiBase={apiBase} onPreview={onPreview} /> : null}
          </View>
        );
      })}
    </View>
  );
}

function ImageGrid({ images, apiBase, onPreview }: { images: Array<{ filename: string; url: string; candidate_id: number }>; apiBase: string; onPreview: (url: string) => void }) {
  return (
    <View style={styles.imageGrid}>
      {images.map((image, index) => {
        const url = resolveImageUrl(apiBase, image.url);
        return (
          <Pressable key={`${image.filename}-${index}`} style={styles.resultImageFrame} onPress={() => onPreview(url)}>
            <Image source={{ uri: url }} style={styles.resultImage} resizeMode="cover" />
            <Text style={styles.resultCaption}>结果图 {image.candidate_id + 1}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function StatusBadge({ status }: { status: string }) {
  return (
    <View style={[styles.statusBadge, statusStyle(status)]}>
      <Text style={styles.statusText}>{STATUS_LABELS[status] || status || '未知'}</Text>
    </View>
  );
}

function AuthModal({
  visible,
  mode,
  email,
  password,
  name,
  error,
  submitting,
  onClose,
  onModeChange,
  onEmailChange,
  onPasswordChange,
  onNameChange,
  onSubmit,
}: {
  visible: boolean;
  mode: AuthMode;
  email: string;
  password: string;
  name: string;
  error: string;
  submitting: boolean;
  onClose: () => void;
  onModeChange: (mode: AuthMode) => void;
  onEmailChange: (value: string) => void;
  onPasswordChange: (value: string) => void;
  onNameChange: (value: string) => void;
  onSubmit: () => void;
}) {
  const isSignUp = mode === 'sign-up';
  const canSubmit = Boolean(email.trim() && password.length >= 8 && !submitting);
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalBackdrop}>
        <View style={styles.authSheet}>
          <View style={styles.sheetTopline}>
            <View>
              <Text style={styles.sheetTitle}>{isSignUp ? '注册账号' : '登录账号'}</Text>
              <Text style={styles.sheetNote}>登录后可以同步查看自己的任务记录。</Text>
            </View>
            <Pressable style={styles.closeButton} onPress={onClose}>
              <X size={20} color="#1b1a16" />
            </Pressable>
          </View>
          {isSignUp ? <LabeledInput label="昵称" value={name} onChangeText={onNameChange} /> : null}
          <LabeledInput label="邮箱" value={email} onChangeText={onEmailChange} autoCapitalize="none" />
          <LabeledInput label="密码" value={password} onChangeText={onPasswordChange} secureTextEntry />
          <Pressable style={[styles.primaryButton, !canSubmit && styles.disabledButton]} disabled={!canSubmit} onPress={onSubmit}>
            {submitting ? <ActivityIndicator color="#fff" /> : <ShieldCheck size={18} color="#fff" />}
            <Text style={styles.primaryButtonText}>{isSignUp ? '注册并登录' : '登录'}</Text>
          </Pressable>
          <Pressable style={styles.textButton} onPress={() => onModeChange(isSignUp ? 'sign-in' : 'sign-up')}>
            <Text style={styles.textButtonText}>{isSignUp ? '已有账号，去登录' : '没有账号，去注册'}</Text>
          </Pressable>
          {error ? <ErrorLine text={error} /> : null}
        </View>
      </View>
    </Modal>
  );
}

function clampNumber(value: string, min: number, max: number, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.round(parsed)));
}

function formatConfigurationMode(mode: string) {
  return mode === 'simple' ? '普通模式' : '专业模式';
}

function statusStyle(status: string) {
  if (status === 'succeeded') return styles.statusSuccess;
  if (status === 'failed') return styles.statusFailed;
  if (status === 'running') return styles.statusRunning;
  return styles.statusQueued;
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f5f2e9',
  },
  flex: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 16,
    paddingTop: 10,
    paddingBottom: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderBottomWidth: 1,
    borderBottomColor: '#ded8cc',
    backgroundColor: '#fffaf0',
  },
  brandRow: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingRight: 10,
  },
  logo: {
    width: 42,
    height: 42,
    borderRadius: 8,
  },
  brandText: {
    flex: 1,
  },
  title: {
    color: '#1b1a16',
    fontSize: 18,
    fontWeight: '800',
  },
  subtitle: {
    color: '#6f6658',
    fontSize: 12,
    marginTop: 2,
  },
  loginPill: {
    minHeight: 36,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d6caba',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#fffdfa',
  },
  loginText: {
    fontSize: 13,
    color: '#1b1a16',
    fontWeight: '700',
  },
  accountPill: {
    maxWidth: 150,
    minHeight: 36,
    paddingHorizontal: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#a8cfc4',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#eff8f4',
  },
  accountText: {
    flex: 1,
    color: '#1f5c55',
    fontSize: 12,
    fontWeight: '700',
  },
  tabs: {
    flexDirection: 'row',
    gap: 8,
    padding: 12,
    backgroundColor: '#fffaf0',
  },
  tabButton: {
    flex: 1,
    minHeight: 38,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d6caba',
    backgroundColor: '#fffdfa',
  },
  tabButtonActive: {
    backgroundColor: '#20766e',
    borderColor: '#20766e',
  },
  tabText: {
    color: '#5f574c',
    fontWeight: '700',
  },
  tabTextActive: {
    color: '#fff',
  },
  scroll: {
    flex: 1,
  },
  content: {
    padding: 16,
    paddingBottom: 32,
    gap: 14,
  },
  healthBanner: {
    borderRadius: 8,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    borderWidth: 1,
  },
  healthOk: {
    backgroundColor: '#edf8f3',
    borderColor: '#add4c9',
  },
  healthWarn: {
    backgroundColor: '#fff4e6',
    borderColor: '#e2bd82',
  },
  healthTextBlock: {
    flex: 1,
  },
  healthTitle: {
    color: '#1b1a16',
    fontSize: 14,
    fontWeight: '800',
  },
  healthNote: {
    color: '#6f6658',
    fontSize: 12,
    lineHeight: 18,
    marginTop: 2,
  },
  refreshIconButton: {
    width: 38,
    height: 38,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fffdfa',
  },
  sectionHeader: {
    marginTop: 2,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  sectionCopy: {
    flex: 1,
  },
  sectionTitle: {
    color: '#1b1a16',
    fontSize: 17,
    fontWeight: '800',
  },
  sectionNote: {
    color: '#6f6658',
    fontSize: 12,
    lineHeight: 18,
    marginTop: 2,
  },
  modeSwitch: {
    flexDirection: 'row',
    gap: 10,
  },
  modeButton: {
    flex: 1,
    minHeight: 62,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d6caba',
    backgroundColor: '#fffdfa',
    paddingHorizontal: 12,
    alignItems: 'center',
    flexDirection: 'row',
    gap: 10,
  },
  modeButtonActive: {
    backgroundColor: '#20766e',
    borderColor: '#20766e',
  },
  modeTitle: {
    color: '#1b1a16',
    fontWeight: '800',
  },
  modeTitleActive: {
    color: '#fff',
  },
  modeSubtitle: {
    color: '#6f6658',
    fontSize: 11,
    marginTop: 2,
  },
  modeSubtitleActive: {
    color: '#d9f4ec',
  },
  providerGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    minHeight: 34,
    paddingHorizontal: 12,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d6caba',
    backgroundColor: '#fffdfa',
  },
  chipActive: {
    backgroundColor: '#20766e',
    borderColor: '#20766e',
  },
  chipText: {
    color: '#50483d',
    fontSize: 13,
    fontWeight: '700',
  },
  chipTextActive: {
    color: '#fff',
  },
  panel: {
    borderWidth: 1,
    borderColor: '#ded8cc',
    backgroundColor: '#fffdfa',
    borderRadius: 8,
    padding: 12,
    gap: 8,
  },
  panelTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  panelTitle: {
    color: '#1b1a16',
    fontSize: 15,
    fontWeight: '800',
  },
  guideLink: {
    alignSelf: 'flex-start',
  },
  guideLinkText: {
    color: '#20766e',
    fontWeight: '800',
  },
  guideStep: {
    color: '#6f6658',
    fontSize: 12,
    lineHeight: 18,
  },
  field: {
    gap: 7,
  },
  compactField: {
    flex: 1,
  },
  fieldLabel: {
    color: '#342f28',
    fontSize: 13,
    fontWeight: '800',
  },
  input: {
    minHeight: 44,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d6caba',
    backgroundColor: '#fffdfa',
    color: '#1b1a16',
    paddingHorizontal: 12,
    paddingVertical: 9,
    fontSize: 14,
  },
  textarea: {
    lineHeight: 20,
  },
  summaryRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  summaryPill: {
    maxWidth: '100%',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#d9bf8b',
    backgroundColor: '#fff4d7',
    paddingHorizontal: 10,
    minHeight: 30,
    justifyContent: 'center',
  },
  summaryText: {
    color: '#7b5519',
    fontSize: 12,
    fontWeight: '800',
  },
  advancedBlock: {
    gap: 12,
  },
  optionGroup: {
    gap: 8,
  },
  optionRow: {
    gap: 8,
    paddingRight: 4,
  },
  inlineInputs: {
    flexDirection: 'row',
    gap: 10,
  },
  switchRow: {
    borderWidth: 1,
    borderColor: '#d6caba',
    borderRadius: 8,
    backgroundColor: '#fffdfa',
    minHeight: 48,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  switchText: {
    color: '#1b1a16',
    fontWeight: '800',
  },
  exampleRow: {
    gap: 10,
    paddingRight: 4,
  },
  exampleCard: {
    width: 230,
    minHeight: 126,
    borderWidth: 1,
    borderColor: '#ded8cc',
    backgroundColor: '#fffdfa',
    borderRadius: 8,
    padding: 12,
    gap: 5,
  },
  exampleLabel: {
    color: '#c16b25',
    fontSize: 11,
    fontWeight: '900',
  },
  exampleTitle: {
    color: '#1b1a16',
    fontSize: 14,
    fontWeight: '800',
  },
  exampleCaption: {
    color: '#5f574c',
    fontSize: 12,
    lineHeight: 17,
  },
  exampleHint: {
    color: '#8a8174',
    fontSize: 11,
    lineHeight: 16,
  },
  categoryNote: {
    color: '#6f6658',
    fontSize: 12,
    lineHeight: 18,
    marginTop: -6,
  },
  primaryButton: {
    minHeight: 48,
    borderRadius: 8,
    backgroundColor: '#20766e',
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 14,
  },
  disabledButton: {
    opacity: 0.48,
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '800',
  },
  secondaryButton: {
    minHeight: 44,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#9fc8bd',
    backgroundColor: '#edf8f3',
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 12,
  },
  secondaryButtonText: {
    color: '#20766e',
    fontWeight: '800',
  },
  textButton: {
    minHeight: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  textButtonText: {
    color: '#20766e',
    fontWeight: '800',
  },
  errorLine: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e1b8ad',
    backgroundColor: '#fff1ee',
    padding: 10,
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  errorText: {
    flex: 1,
    color: '#933522',
    fontSize: 13,
    lineHeight: 18,
  },
  emptyBox: {
    minHeight: 112,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: '#d6caba',
    borderRadius: 8,
    backgroundColor: '#fffdfa',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    gap: 6,
  },
  emptyTitle: {
    color: '#1b1a16',
    fontWeight: '800',
  },
  emptyNote: {
    color: '#6f6658',
    fontSize: 12,
    lineHeight: 18,
    textAlign: 'center',
  },
  statePanel: {
    borderWidth: 1,
    borderColor: '#ded8cc',
    backgroundColor: '#fffdfa',
    borderRadius: 8,
    padding: 16,
    gap: 10,
  },
  stateTitle: {
    color: '#1b1a16',
    fontSize: 16,
    fontWeight: '800',
  },
  stateNote: {
    color: '#6f6658',
    fontSize: 13,
    lineHeight: 19,
  },
  jobList: {
    gap: 12,
  },
  jobCard: {
    borderWidth: 1,
    borderColor: '#ded8cc',
    backgroundColor: '#fffdfa',
    borderRadius: 8,
    padding: 12,
    gap: 10,
  },
  jobTopline: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  jobId: {
    flex: 1,
    color: '#8a8174',
    fontSize: 11,
  },
  jobDate: {
    marginLeft: 'auto',
    color: '#8a8174',
    fontSize: 12,
  },
  jobCaption: {
    color: '#1b1a16',
    fontSize: 15,
    fontWeight: '800',
    lineHeight: 20,
  },
  jobMetaRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 7,
  },
  jobMeta: {
    color: '#6f6658',
    fontSize: 12,
    backgroundColor: '#f5f2e9',
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 4,
    overflow: 'hidden',
  },
  userEmail: {
    color: '#20766e',
    fontSize: 12,
    fontWeight: '800',
  },
  modelsBlock: {
    gap: 4,
  },
  modelText: {
    color: '#5f574c',
    fontSize: 12,
  },
  methodPreview: {
    color: '#6f6658',
    fontSize: 12,
    lineHeight: 18,
  },
  imageGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  resultImageFrame: {
    width: '48%',
    borderRadius: 8,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#ded8cc',
    backgroundColor: '#f5f2e9',
  },
  resultImage: {
    width: '100%',
    aspectRatio: 1.35,
    backgroundColor: '#ebe5d9',
  },
  resultCaption: {
    color: '#5f574c',
    fontSize: 11,
    fontWeight: '700',
    padding: 8,
  },
  statusBadge: {
    borderRadius: 8,
    paddingHorizontal: 8,
    minHeight: 26,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statusQueued: {
    backgroundColor: '#fff4d7',
  },
  statusRunning: {
    backgroundColor: '#e6f1ff',
  },
  statusSuccess: {
    backgroundColor: '#e4f6ed',
  },
  statusFailed: {
    backgroundColor: '#ffe8e3',
  },
  statusText: {
    color: '#1b1a16',
    fontSize: 12,
    fontWeight: '800',
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(17, 24, 39, 0.38)',
    justifyContent: 'flex-end',
  },
  authSheet: {
    backgroundColor: '#fffdfa',
    borderTopLeftRadius: 8,
    borderTopRightRadius: 8,
    padding: 16,
    gap: 12,
  },
  sheetTopline: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  sheetTitle: {
    color: '#1b1a16',
    fontSize: 18,
    fontWeight: '800',
  },
  sheetNote: {
    color: '#6f6658',
    fontSize: 12,
    marginTop: 2,
  },
  closeButton: {
    width: 38,
    height: 38,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f5f2e9',
  },
  previewBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.92)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  previewClose: {
    position: 'absolute',
    top: 52,
    right: 18,
    width: 42,
    height: 42,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.18)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2,
  },
  previewImage: {
    width: '100%',
    height: '82%',
  },
});
