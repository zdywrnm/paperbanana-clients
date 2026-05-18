import { BACKEND_MODE } from '../config';
import { lafEndpoint, normalizeJob, shouldUseLaf, toLafPipeline } from '../utils';
import { fetchJson } from './client';

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

export async function getJobRequest(apiBase, health, jobId) {
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

export async function adminJobsRequest(apiBase, health, adminToken) {
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

export async function hydrateRecordImages(apiBase, health, jobs) {
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
