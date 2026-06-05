import { fetchJson } from './client';

const BACKEND_MODE = import.meta.env.VITE_BACKEND_MODE || '';

export async function fetchBackendHealth(apiBase) {
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

export async function createJobRequest(apiBase, health, payload) {
  if (shouldUsePaperbananaApi(apiBase, health)) {
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
        outputFormat: payload.outputFormat,
        mainModelName: payload.mainModelName,
        imageModelName: payload.imageGenModelName,
        referenceVisionModelName: payload.referenceVisionModelName,
        referenceImages: payload.referenceImages || [],
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
      output_format: payload.outputFormat,
      main_model_name: payload.mainModelName,
      image_gen_model_name: payload.imageGenModelName,
      reference_vision_model_name: payload.referenceVisionModelName,
      reference_images: payload.referenceImages || [],
      pipeline_mode: payload.pipelineMode,
      retrieval_setting: payload.retrievalSetting,
      aspect_ratio: payload.aspectRatio,
      num_candidates: payload.numCandidates,
      max_critic_rounds: payload.maxCriticRounds,
      mock: payload.mock,
    }),
  });
}

export async function prepareReferenceUploadRequest(apiBase, health, files) {
  if (shouldUsePaperbananaApi(apiBase, health)) {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'prepareReferenceUpload', files }),
    });
    return { uploads: data.uploads || [] };
  }

  throw new Error('参考图上传需要使用 Laf 或登录网关后端。');
}

export async function getJobRequest(apiBase, health, jobId, options = {}) {
  if (shouldUseLaf(apiBase, health)) {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'getJob', jobId, adminToken: options.adminToken || undefined }),
    });
    return normalizeJob(data.job);
  }
  return fetchJson(`${apiBase}/api/jobs/${jobId}`);
}

export async function adminJobsRequest(apiBase, health, adminToken) {
  if (shouldUseLaf(apiBase, health)) {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'adminJobs', adminToken, limit: 50 }),
    });
    const jobs = (data.jobs || []).map(normalizeJob);
    return { jobs: await hydrateRecordImages(apiBase, health, jobs, { adminToken }) };
  }
  return fetchJson(`${apiBase}/api/admin/jobs?limit=50`, {
    headers: { 'x-admin-token': adminToken },
  });
}

export async function adminUsersRequest(apiBase, health, adminToken) {
  if (BACKEND_MODE === 'gateway' || health?.backendMode === 'gateway') {
    const data = await fetchJson(lafEndpoint(apiBase), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'adminUsers', adminToken, limit: 100 }),
    });
    return { users: (data.users || []).map(normalizeAuthUser) };
  }
  throw new Error('账号后台需要先启用登录网关。');
}

export async function userJobsRequest(apiBase, health) {
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

export async function hydrateRecordImages(apiBase, health, jobs, options = {}) {
  return Promise.all(jobs.map(async (job) => {
    const images = job.result_images || [];
    const references = job.reference_images || [];
    const hasResult = job.result_image_count > 0 || images.length > 0;
    const hasReference = job.reference_image_count > 0 || references.length > 0;
    const allImages = [...images, ...references];
    const needsFreshDetail = allImages.some((image) => image.storage === 'bucket' || (image.url && !image.url.startsWith('data:')));
    if (job.status !== 'succeeded' && !hasReference) return job;
    if (!hasResult && !hasReference && !needsFreshDetail) return job;
    try {
      const detail = await getJobRequest(apiBase, health, job.id, options);
      return { ...job, ...detail };
    } catch {
      return job;
    }
  }));
}

function shouldUsePaperbananaApi(apiBase, health) {
  return BACKEND_MODE === 'gateway' || health?.backendMode === 'gateway' || shouldUseLaf(apiBase, health);
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
    output_format: job.output_format || job.outputFormat || 'png',
    main_model_name: job.main_model_name || job.mainModelName || '',
    image_gen_model_name: job.image_gen_model_name || job.imageModelName || '',
    reference_vision_model_name: job.reference_vision_model_name || job.referenceVisionModelName || '',
    pipeline_mode: job.pipeline_mode || job.pipelineMode || '',
    aspect_ratio: job.aspect_ratio || job.aspectRatio || '',
    num_candidates: job.num_candidates || job.numCandidates || 0,
    max_critic_rounds: job.max_critic_rounds || job.maxCriticRounds || 0,
    prompt_char_count: job.prompt_char_count || job.promptCharCount || 0,
    result_image_count: job.result_image_count || job.resultImageCount || (job.result_images || job.resultImages || []).length || 0,
    result_images: (job.result_images || job.resultImages || []).map((image, index) => ({
      filename: image.filename || image.url || `${index}`,
      url: image.url,
      storage: image.storage || '',
      candidate_id: image.candidate_id ?? image.candidateId ?? index,
      mime_type: image.mime_type || image.mimeType || '',
    })),
    reference_image_count: job.reference_image_count || job.referenceImageCount || (job.reference_images || job.referenceImages || []).length || 0,
    reference_images: (job.reference_images || job.referenceImages || []).map((image, index) => ({
      filename: image.filename || `reference-${index + 1}`,
      object_key: image.object_key || image.objectKey || '',
      url: image.url,
      storage: image.storage || '',
      mime_type: image.mime_type || image.mimeType || '',
      size: Number(image.size || 0),
    })),
    logs_tail: job.logs_tail || (Array.isArray(job.logs) ? job.logs.slice(-10).join('\n') : ''),
    error: job.error || '',
    created_at: job.created_at || job.createdAt,
    updated_at: job.updated_at || job.updatedAt,
    started_at: job.started_at || job.startedAt,
    completed_at: job.completed_at || job.completedAt,
  };
}

function normalizeAuthUser(user = {}) {
  return {
    id: user.id || user._id || '',
    email: user.email || '',
    name: user.name || '',
    email_verified: Boolean(user.email_verified ?? user.emailVerified),
    image: user.image || '',
    created_at: user.created_at || user.createdAt,
    updated_at: user.updated_at || user.updatedAt,
    last_login_at: user.last_login_at || user.lastLoginAt,
    session_count: Number(user.session_count ?? user.sessionCount ?? 0),
    last_ip_address: user.last_ip_address || user.lastIpAddress || '',
    last_user_agent: user.last_user_agent || user.lastUserAgent || '',
  };
}
