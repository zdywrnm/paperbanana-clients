import cloud from '@lafjs/cloud'

type Provider = 'openrouter' | 'gemini' | 'openai' | 'bailian'
type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed'

type ApiKeys = {
  openrouter?: string
  gemini?: string
  openai?: string
  bailian?: string
}

type CreateJobBody = {
  action: 'createJob'
  provider: Provider
  apiKeys: ApiKeys
  methodContent: string
  caption: string
  mainModelName: string
  imageModelName: string
  pipelineMode?: 'planner_critic' | 'full' | 'vanilla'
  aspectRatio?: '16:9' | '21:9' | '3:2' | '1:1'
  numCandidates?: number
  maxCriticRounds?: number
}

type GetJobBody = {
  action: 'getJob'
  jobId: string
}

type AdminJobsBody = {
  action: 'adminJobs'
  adminToken: string
  limit?: number
}

type HealthBody = {
  action: 'health'
}

type RequestBody = CreateJobBody | GetJobBody | AdminJobsBody | HealthBody

const db = cloud.mongo.db
const jobs = db.collection('paperbanana_jobs')
const bucketName = process.env.PAPERBANANA_BUCKET || 'paperbanana'

export default async function (ctx: FunctionContext) {
  setCorsHeaders(ctx)
  if (ctx.request?.method === 'OPTIONS') {
    ctx.response.status(204)
    return ''
  }

  const body = normalizeBody(ctx.body) as RequestBody
  const action = body?.action || 'health'

  try {
    if (action === 'health') {
      return ok({ ok: true, runtime: 'laf', version: '0.1.1' })
    }
    if (action === 'createJob') {
      return await createJob(body as CreateJobBody, ctx)
    }
    if (action === 'getJob') {
      return await getJob((body as GetJobBody).jobId)
    }
    if (action === 'adminJobs') {
      return await adminJobs(body as AdminJobsBody)
    }
    return fail(`Unknown action: ${action}`, 400)
  } catch (error: any) {
    return fail(error?.message || String(error), 500)
  }
}

function setCorsHeaders(ctx: FunctionContext) {
  ctx.response.setHeader('Access-Control-Allow-Origin', '*')
  ctx.response.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
  ctx.response.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-Admin-Token')
  ctx.response.setHeader('Access-Control-Max-Age', '86400')
}

async function createJob(body: CreateJobBody, ctx: FunctionContext) {
  validateCreateBody(body)
  const apiKey = selectApiKey(body.provider, body.apiKeys)
  if (!apiKey) {
    return fail(`Missing API key for provider ${body.provider}`, 400)
  }

  const now = new Date()
  const jobId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  const safeNumCandidates = clamp(Number(body.numCandidates || 1), 1, Number(process.env.PAPERBANANA_MAX_CANDIDATES || 3))
  const safeCriticRounds = clamp(Number(body.maxCriticRounds || 1), 0, Number(process.env.PAPERBANANA_MAX_CRITIC_ROUNDS || 2))

  const record = {
    _id: jobId,
    status: 'queued' as JobStatus,
    provider: body.provider,
    methodContent: body.methodContent,
    caption: body.caption,
    mainModelName: body.mainModelName,
    imageModelName: body.imageModelName,
    pipelineMode: body.pipelineMode || 'planner_critic',
    aspectRatio: body.aspectRatio || '16:9',
    numCandidates: safeNumCandidates,
    maxCriticRounds: safeCriticRounds,
    promptCharCount: body.methodContent.length + body.caption.length,
    resultImages: [],
    logs: [],
    error: '',
    clientIp: getClientIp(ctx),
    userAgent: ctx.headers?.['user-agent'] || '',
    createdAt: now,
    updatedAt: now,
    startedAt: null,
    completedAt: null,
  }

  await jobs.insertOne(record)

  // Laf 云函数是常驻 Node.js Runtime。API key 只保留在本次闭包中，
  // 不写入数据库，不进入日志。
  void runJob(jobId, body, apiKey, safeNumCandidates, safeCriticRounds).catch(async (error) => {
    await markFailed(jobId, error?.message || String(error))
  })

  return ok({ jobId, status: 'queued' })
}

async function getJob(jobId: string) {
  if (!jobId) return fail('jobId is required', 400)
  const job = await jobs.findOne({ _id: jobId })
  if (!job) return fail('Job not found', 404)
  return ok({ job: publicJob(job) })
}

async function adminJobs(body: AdminJobsBody) {
  const expected = process.env.ADMIN_TOKEN || ''
  if (!expected) return fail('Admin API disabled: ADMIN_TOKEN is not configured', 503)
  if (body.adminToken !== expected) return fail('Invalid admin token', 401)
  const limit = clamp(Number(body.limit || 50), 1, 200)
  const list = await jobs.find({}).sort({ createdAt: -1 }).limit(limit).toArray()
  return ok({ jobs: list.map(publicJob) })
}

async function runJob(
  jobId: string,
  body: CreateJobBody,
  apiKey: string,
  numCandidates: number,
  maxCriticRounds: number,
) {
  await jobs.updateOne(
    { _id: jobId },
    { $set: { status: 'running', startedAt: new Date(), updatedAt: new Date() } },
  )

  const results = []
  for (let i = 0; i < numCandidates; i += 1) {
    await appendLog(jobId, `Candidate ${i + 1}: planning`)
    const image = await runCandidate(body, apiKey, maxCriticRounds)
    const saved = await saveImage(jobId, i, image.base64, image.mimeType)
    results.push({
      candidateId: i,
      url: saved.url,
      storage: saved.storage,
      mimeType: image.mimeType,
      description: image.description,
    })
  }

  await jobs.updateOne(
    { _id: jobId },
    {
      $set: {
        status: 'succeeded',
        resultImages: results,
        completedAt: new Date(),
        updatedAt: new Date(),
      },
    },
  )
}

async function runCandidate(body: CreateJobBody, apiKey: string, maxCriticRounds: number) {
  if ((body.pipelineMode || 'planner_critic') === 'vanilla') {
    const prompt = diagramPrompt(body.methodContent, body.caption)
    const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, prompt, body.aspectRatio || '16:9')
    return { base64, mimeType: 'image/png', description: prompt }
  }

  const planner = await callTextModel(
    body.provider,
    body.mainModelName,
    apiKey,
    plannerSystemPrompt(),
    plannerUserPrompt(body.methodContent, body.caption),
  )

  let description = planner
  if ((body.pipelineMode || 'planner_critic') === 'full') {
    description = await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      stylistSystemPrompt(),
      stylistUserPrompt(body.methodContent, body.caption, planner),
    )
  }

  let imagePrompt = diagramPromptFromDescription(description)
  let base64 = await callImageModel(body.provider, body.imageModelName, apiKey, imagePrompt, body.aspectRatio || '16:9')

  for (let round = 0; round < maxCriticRounds; round += 1) {
    const critique = await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      criticSystemPrompt(),
      criticUserPrompt(body.methodContent, body.caption, description),
    )
    if (/no changes needed/i.test(critique)) break
    description = critique
    imagePrompt = diagramPromptFromDescription(description)
    base64 = await callImageModel(body.provider, body.imageModelName, apiKey, imagePrompt, body.aspectRatio || '16:9')
  }

  return { base64, mimeType: 'image/png', description }
}

async function callTextModel(provider: Provider, model: string, apiKey: string, system: string, user: string): Promise<string> {
  if (provider === 'gemini') {
    return callGeminiText(model, apiKey, system, user)
  }
  const baseUrl = textApiBaseUrl(provider)
  const actualModel = provider === 'openrouter' ? toOpenRouterModel(model) : model
  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: actualModel,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      temperature: 1,
    }),
  })
  const data = await parseModelResponse(response)
  return data.choices?.[0]?.message?.content || ''
}

async function callImageModel(provider: Provider, model: string, apiKey: string, prompt: string, aspectRatio: string): Promise<string> {
  if (provider === 'openai') {
    const response = await fetch('https://api.openai.com/v1/images/generations', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        prompt,
        size: '1536x1024',
        quality: 'high',
        background: 'opaque',
        output_format: 'png',
      }),
    })
    const data = await parseModelResponse(response)
    return data.data?.[0]?.b64_json
  }

  if (provider === 'gemini') {
    return callGeminiImage(model, apiKey, prompt, aspectRatio)
  }

  if (provider === 'bailian') {
    return callBailianImage(model, apiKey, prompt, aspectRatio)
  }

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: toOpenRouterModel(model),
      messages: [{ role: 'user', content: [{ type: 'text', text: prompt }] }],
      modalities: ['image', 'text'],
      image_config: {
        aspect_ratio: aspectRatio,
        image_size: '1k',
      },
    }),
  })
  const data = await parseModelResponse(response)
  const message = data.choices?.[0]?.message || {}
  const imageUrl = message.images?.[0]?.image_url?.url || ''
  if (imageUrl.includes(',')) return imageUrl.split(',', 2)[1]
  if (typeof message.content === 'string' && message.content.startsWith('data:image')) {
    return message.content.split(',', 2)[1]
  }
  throw new Error('Image model did not return image data')
}

function textApiBaseUrl(provider: Provider) {
  if (provider === 'openrouter') return 'https://openrouter.ai/api/v1'
  if (provider === 'bailian') return 'https://dashscope.aliyuncs.com/compatible-mode/v1'
  return 'https://api.openai.com/v1'
}

async function callGeminiText(model: string, apiKey: string, system: string, user: string): Promise<string> {
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: 'user', parts: [{ text: user }] }],
      generationConfig: { temperature: 1 },
    }),
  })
  const data = await parseModelResponse(response)
  return data.candidates?.[0]?.content?.parts?.map((part: any) => part.text || '').join('') || ''
}

async function callGeminiImage(model: string, apiKey: string, prompt: string, aspectRatio: string): Promise<string> {
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        responseModalities: ['IMAGE'],
        imageConfig: { aspectRatio, imageSize: '1K' },
      },
    }),
  })
  const data = await parseModelResponse(response)
  for (const part of data.candidates?.[0]?.content?.parts || []) {
    if (part.inlineData?.data) return part.inlineData.data
    if (part.inline_data?.data) return part.inline_data.data
  }
  throw new Error('Gemini image model did not return image data')
}

async function callBailianImage(model: string, apiKey: string, prompt: string, aspectRatio: string): Promise<string> {
  const response = await fetch('https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      input: {
        messages: [
          {
            role: 'user',
            content: [{ text: prompt }],
          },
        ],
      },
      parameters: {
        size: bailianImageSize(aspectRatio),
        n: 1,
        watermark: false,
      },
    }),
  })
  const data = await parseDashScopeResponse(response)
  const imageUrl = extractDashScopeImageUrl(data)
  if (!imageUrl) throw new Error('阿里百炼图片模型没有返回图片地址')
  return await fetchImageAsBase64(imageUrl)
}

function extractDashScopeImageUrl(data: any) {
  const contents = data?.output?.choices?.[0]?.message?.content || []
  for (const item of contents) {
    if (item?.type === 'image' && item?.image) return item.image
    if (item?.image) return item.image
  }
  return ''
}

function bailianImageSize(aspectRatio: string) {
  if (aspectRatio === '21:9') return '1792*768'
  if (aspectRatio === '3:2') return '1536*1024'
  if (aspectRatio === '1:1') return '1024*1024'
  return '1536*864'
}

async function fetchImageAsBase64(url: string) {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`下载阿里百炼生成图片失败：HTTP ${response.status}`)
  const arrayBuffer = await response.arrayBuffer()
  return Buffer.from(arrayBuffer).toString('base64')
}

async function saveImage(jobId: string, candidateId: number, base64: string, mimeType: string) {
  const filename = `${jobId}/candidate-${candidateId}.png`
  try {
    const bucket = cloud.storage.bucket(bucketName)
    await bucket.writeFile(filename, Buffer.from(base64, 'base64'), { ContentType: mimeType })
    return {
      storage: 'bucket',
      url: await bucket.getDownloadUrl(filename, 3600 * 24 * 7),
    }
  } catch (error: any) {
    return {
      storage: 'database-data-url',
      url: `data:${mimeType};base64,${base64}`,
      storageError: error?.message || String(error),
    }
  }
}

async function markFailed(jobId: string, error: string) {
  await jobs.updateOne(
    { _id: jobId },
    {
      $set: {
        status: 'failed',
        error,
        completedAt: new Date(),
        updatedAt: new Date(),
      },
      $push: { logs: `ERROR: ${error}` },
    },
  )
}

async function appendLog(jobId: string, message: string) {
  await jobs.updateOne(
    { _id: jobId },
    {
      $set: { updatedAt: new Date() },
      $push: { logs: `${new Date().toISOString()} ${message}` },
    },
  )
}

async function parseModelResponse(response: Response) {
  const text = await response.text()
  let data: any = {}
  try {
    data = text ? JSON.parse(text) : {}
  } catch {
    data = { raw: text }
  }
  if (!response.ok) {
    throw new Error(data?.error?.message || data?.message || text || `HTTP ${response.status}`)
  }
  return data
}

async function parseDashScopeResponse(response: Response) {
  const data = await parseModelResponse(response)
  if (data?.status_code && data.status_code !== 200) {
    throw new Error(data?.message || data?.code || `DashScope HTTP ${data.status_code}`)
  }
  if (data?.code) {
    throw new Error(data?.message || data.code)
  }
  return data
}

function plannerSystemPrompt() {
  return [
    'You are the Planner Agent for PaperBanana.',
    'Given a paper methodology section and figure caption, write a detailed visual specification for a publication-quality academic diagram.',
    'Describe semantic components, layout, arrows, labels, colors, background, spacing, and icon style.',
    'Do not include the figure title or caption text inside the image.',
  ].join('\n')
}

function plannerUserPrompt(method: string, caption: string) {
  return `Methodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nDetailed description of the target figure:`
}

function stylistSystemPrompt() {
  return [
    'You are the Stylist Agent for PaperBanana.',
    'Refine the visual specification for a clean NeurIPS-style academic diagram.',
    'Preserve semantics. Improve layout clarity, typography, color harmony, line thickness, and whitespace.',
  ].join('\n')
}

function stylistUserPrompt(method: string, caption: string, description: string) {
  return `Initial Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nPolished detailed description:`
}

function criticSystemPrompt() {
  return [
    'You are the Critic Agent for PaperBanana.',
    'Check whether the current diagram description matches the methodology and caption.',
    'If changes are needed, return a revised detailed description only.',
    'If it is already good, return exactly: No changes needed.',
  ].join('\n')
}

function criticUserPrompt(method: string, caption: string, description: string) {
  return `Current Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nCritique or revised description:`
}

function diagramPrompt(method: string, caption: string) {
  return diagramPromptFromDescription(
    `Create an academic method diagram for this methodology:\n${method}\n\nVisual intent:\n${caption}`,
  )
}

function diagramPromptFromDescription(description: string) {
  return [
    'Render a high-quality scientific diagram based on the following detailed description.',
    'Use a clean white or very light background, crisp vector-like shapes, readable labels, professional academic style.',
    'Do not include a figure title or caption inside the image.',
    '',
    description,
  ].join('\n')
}

function validateCreateBody(body: CreateJobBody) {
  if (!['openrouter', 'gemini', 'openai', 'bailian'].includes(body.provider)) throw new Error('Invalid provider')
  if (!body.methodContent || body.methodContent.trim().length < 20) throw new Error('methodContent is too short')
  if (!body.caption || body.caption.trim().length < 3) throw new Error('caption is required')
  if (!body.mainModelName) throw new Error('mainModelName is required')
  if (!body.imageModelName) throw new Error('imageModelName is required')
}

function selectApiKey(provider: Provider, apiKeys: ApiKeys) {
  if (provider === 'openrouter') return apiKeys?.openrouter?.trim() || ''
  if (provider === 'gemini') return apiKeys?.gemini?.trim() || ''
  if (provider === 'openai') return apiKeys?.openai?.trim() || ''
  if (provider === 'bailian') return apiKeys?.bailian?.trim() || ''
  return ''
}

function publicJob(job: any) {
  return {
    id: job._id,
    status: job.status,
    provider: job.provider,
    methodContent: job.methodContent,
    caption: job.caption,
    mainModelName: job.mainModelName,
    imageModelName: job.imageModelName,
    pipelineMode: job.pipelineMode,
    aspectRatio: job.aspectRatio,
    numCandidates: job.numCandidates,
    maxCriticRounds: job.maxCriticRounds,
    promptCharCount: job.promptCharCount,
    resultImages: job.resultImages || [],
    logs: job.logs || [],
    error: job.error || '',
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    startedAt: job.startedAt,
    completedAt: job.completedAt,
  }
}

function ok(data: any) {
  return { code: 0, ...data }
}

function fail(message: string, status = 400) {
  return { code: status, error: message }
}

function normalizeBody(body: any) {
  if (typeof body === 'string') {
    try {
      return JSON.parse(body)
    } catch {
      return {}
    }
  }
  return body || {}
}

function getClientIp(ctx: FunctionContext) {
  const forwarded = ctx.headers?.['x-forwarded-for']
  if (Array.isArray(forwarded)) return forwarded[0] || ''
  return forwarded || ctx.headers?.['x-real-ip'] || ''
}

function toOpenRouterModel(model: string) {
  const raw = model.replace(/^openrouter\//, '')
  if (raw.includes('/')) return raw
  if (raw.startsWith('gemini')) return `google/${raw}`
  return raw
}

function clamp(value: number, min: number, max: number) {
  if (Number.isNaN(value)) return min
  return Math.max(min, Math.min(value, max))
}
