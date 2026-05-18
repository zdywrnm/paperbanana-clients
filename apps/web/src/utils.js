import { BACKEND_MODE } from './config';

export function shouldUseLaf(apiBase, health) {
  if (BACKEND_MODE === 'fastapi') return false;
  if (BACKEND_MODE === 'gateway') return true;
  if (BACKEND_MODE === 'laf') return true;
  if (health?.backendMode) return health.backendMode === 'laf';
  return apiBase.includes('paperbanana-api') || apiBase === '';
}

export function lafEndpoint(apiBase) {
  if (apiBase.endsWith('/paperbanana-api')) return apiBase;
  return `${apiBase}/paperbanana-api`;
}

export function toLafPipeline(mode) {
  if (mode === 'demo_full') return 'full';
  if (mode === 'vanilla') return 'vanilla';
  return 'planner_critic';
}

export function normalizeJob(job = {}) {
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

export function resolveImageUrl(apiBase, url) {
  if (!url) return '';
  if (/^(https?:|data:|blob:)/i.test(url)) return url;
  return `${apiBase}${url}`;
}

export function formatErrorMessage(message) {
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

export function formatConfigurationMode(mode) {
  return mode === 'simple' ? '普通模式' : '专业模式';
}

export function formatDate(value) {
  if (!value) return '';
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}
