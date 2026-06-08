import cloud from '@lafjs/cloud'
import * as crypto from 'crypto'

declare const require: any

type Provider = 'openrouter' | 'gemini' | 'openai' | 'bailian'
type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed'
type OutputFormat = 'png' | 'svg'
type TaskName = 'diagram' | 'plot'
type RetrievalSetting = 'none' | 'auto' | 'random' | 'manual'
type ReferenceImageRole = 'original' | 'analysis'
type ReferenceImageMode = 'auto' | 'main_model' | 'vision_model'
type ReferenceImageModeUsed = 'none' | 'main_model' | 'vision_model'
type ModelCapabilityStatus = 'supported' | 'unsupported' | 'unknown'
type FeedbackCategory = 'bug' | 'feature' | 'experience' | 'other'
type FeedbackPlatform = 'web' | 'miniprogram' | 'android' | 'windows' | 'macos'

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
  configurationMode?: string
  taskName?: TaskName
  methodContent: string
  caption: string
  infographicCategory?: string
  userId?: string
  userEmail?: string
  outputFormat?: OutputFormat
  output_format?: OutputFormat
  mainModelName: string
  imageModelName: string
  referenceVisionModelName?: string
  referenceImageMode?: ReferenceImageMode
  referenceImageModeUsed?: ReferenceImageModeUsed
  referenceImages?: ReferenceImageInput[]
  pipelineMode?: 'planner_critic' | 'full' | 'vanilla'
  retrievalSetting?: RetrievalSetting
  manualReferenceIds?: string[]
  aspectRatio?: '16:9' | '21:9' | '3:2' | '1:1'
  numCandidates?: number
  maxCriticRounds?: number
}

type RefineImageBody = {
  action: 'refineImage'
  provider: Provider
  apiKeys: ApiKeys
  mainModelName?: string
  imageModelName: string
  sourceImageUrl?: string
  sourceImageObjectKey?: string
  editInstruction: string
  aspectRatio?: '16:9' | '21:9' | '3:2' | '1:1'
  imageSize?: '2K' | '4K'
  userId?: string
  userEmail?: string
}

type PrepareReferenceUploadBody = {
  action: 'prepareReferenceUpload'
  files?: ReferenceUploadDescriptor[]
  userId?: string
  userEmail?: string
}

type ReferenceUploadDescriptor = {
  clientId?: string
  role?: ReferenceImageRole
  filename: string
  mimeType: string
  size: number
}

type ReferenceImageInput = {
  filename: string
  mimeType: string
  size: number
  objectKey: string
  uploadToken?: string
  analysisObjectKey?: string
  analysisMimeType?: string
  analysisSize?: number
  analysisUploadToken?: string
}

type StoredReferenceImage = {
  filename: string
  mimeType: string
  size: number
  objectKey: string
  storage: 'bucket'
  analysisObjectKey?: string
  analysisMimeType?: string
  analysisSize?: number
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

type SubmitFeedbackBody = {
  action: 'submitFeedback'
  message: string
  category?: FeedbackCategory
  jobId?: string
  platform: FeedbackPlatform
  clientVersion?: string
  contact?: string
  userId?: string
  userEmail?: string
}

type AdminFeedbackBody = {
  action: 'adminFeedback'
  adminToken: string
  limit?: number
  status?: string
}

type UserJobsBody = {
  action: 'userJobs'
  userId: string
  userEmail?: string
  limit?: number
}

type ImportReferencesBody = {
  action: 'importReferences'
  adminToken: string
  mode?: 'probe' | 'inspect' | 'import'
  limit?: number
  offset?: number
  taskName?: string
  zipUrl?: string
}

type ModelCapabilityBody = {
  action: 'modelCapability'
  provider: Provider
  model: string
}

type ReferenceLibraryBody = {
  action: 'referenceLibrary'
  taskName?: TaskName
  query?: string
  limit?: number
}

type HealthBody = {
  action: 'health'
}

type ModelCapabilityResult = {
  status: ModelCapabilityStatus
  supportsReferenceImages: boolean
  reason: string
  source: string
  cached: boolean
}

type VisionImageInput = {
  filename: string
  mimeType: string
  url: string
}

type ResvgWasmModule = {
  initWasm: (bytes: any) => Promise<void> | void
  Resvg: any
}

type RetrievedReference = {
  id: string
  taskName: TaskName
  title: string
  summary: string
  imageUrl: string
  imageObjectKey: string
  source: string
}

type JobStage = {
  id: string
  candidateId: number
  type: string
  title: string
  round?: number
  text?: string
  suggestion?: string
  image?: any
  startedAt: Date
  completedAt: Date
  durationMs: number
  error?: string
}

type RequestBody =
  | CreateJobBody
  | RefineImageBody
  | PrepareReferenceUploadBody
  | GetJobBody
  | AdminJobsBody
  | SubmitFeedbackBody
  | AdminFeedbackBody
  | UserJobsBody
  | ModelCapabilityBody
  | ReferenceLibraryBody
  | ImportReferencesBody
  | HealthBody

const db = cloud.mongo.db
const jobs = db.collection('paperbanana_jobs')
const feedback = db.collection('paperbanana_feedback')
const references = db.collection('paperbanana_references')
const bucketName = process.env.PAPERBANANA_BUCKET || 'paperbanana'
const maxReferenceImages = Number(process.env.PAPERBANANA_MAX_REFERENCE_IMAGES || 3)
const maxReferenceBytes = Number(process.env.PAPERBANANA_MAX_REFERENCE_BYTES || 5 * 1024 * 1024)
const referenceUploadTtlSeconds = Number(process.env.PAPERBANANA_REFERENCE_UPLOAD_TTL_SECONDS || 900)
const allowedReferenceMimeTypes = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
const allowedAnalysisMimeTypes = new Set(['image/png', 'image/jpeg', 'image/webp'])
const svgReferenceRasterWidth = clamp(Number(process.env.PAPERBANANA_SVG_REFERENCE_RASTER_WIDTH || 1024), 320, 1536)
const openRouterModelCacheTtlMs = Number(process.env.OPENROUTER_MODEL_CACHE_TTL_MS || 3600 * 1000)
const feedbackRateLimitWindowMs = 10 * 60 * 1000
const feedbackRateLimitMax = 5
const allowedFeedbackCategories = new Set<FeedbackCategory>(['bug', 'feature', 'experience', 'other'])
const allowedFeedbackPlatforms = new Set<FeedbackPlatform>(['web', 'miniprogram', 'android', 'windows', 'macos'])
const allowedRetrievalSettings = new Set<RetrievalSetting>(['none', 'auto', 'random', 'manual'])
let openRouterModelCache: { expiresAt: number; modalities: Map<string, string[]> } | null = null
let resvgWasmPromise: Promise<ResvgWasmModule> | null = null

const benchZipUrlDefault = 'https://huggingface.co/datasets/dwzhu/PaperBananaBench/resolve/main/PaperBananaBench.zip'
const benchZipCachePath = '/tmp/paperbananabench.zip'
type BenchImportCache = {
  zipUrl: string
  zipBytes: number
  entries: Record<string, Uint8Array>
  entryNames: string[]
  refDir: string
  refItems: any[]
}
let importCache: BenchImportCache | null = null

const openaiVisionMainModels = new Set([
  'gpt-4.1',
  'gpt-4.1-mini',
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-5.1',
  'gpt-5-mini',
  'gpt-5.2',
  'gpt-5.3-chat',
  'gpt-5.4',
  'gpt-5.4-pro',
  'gpt-5.4-mini',
  'gpt-5.4-nano',
  'gpt-5.5',
  'gpt-5.5-pro',
  'gpt-chat-latest',
])

const geminiVisionMainModels = new Set([
  'gemini-2.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-3-flash',
  'gemini-3-flash-preview',
  'gemini-3-pro-preview',
  'gemini-3.1-pro',
  'gemini-3.1-pro-preview',
  'gemini-3.1-flash-lite',
  'gemini-3.1-flash-lite-preview',
  'gemini-3.5-flash',
])

const fallbackReferences: RetrievedReference[] = [
  {
    id: 'paperbanana-style-agent-flow',
    taskName: 'diagram',
    title: 'Agent workflow with retrieval, planning, generation, and critique',
    summary: 'Use a left-to-right multi-agent workflow: input paper content, retrieval examples, planner, stylist, visualizer, critic loop, and final figure. Group agents in soft rounded containers with arrows showing feedback.',
    imageUrl: '',
    imageObjectKey: '',
    source: 'paperbanana-fallback',
  },
  {
    id: 'paperbanana-style-model-pipeline',
    taskName: 'diagram',
    title: 'Academic model pipeline with modules and tensor/data flow',
    summary: 'Use a modular scientific diagram with input data on the left, stacked processing blocks in the center, auxiliary losses or memory paths in dashed connectors, and output artifacts on the right.',
    imageUrl: '',
    imageObjectKey: '',
    source: 'paperbanana-fallback',
  },
  {
    id: 'paperbanana-style-macro-micro',
    taskName: 'diagram',
    title: 'Macro-micro layout with zoomed module detail',
    summary: 'Use one large system container plus a zoomed-in breakout box for an important module. Connect the high-level block to the detail view with thin lines and keep labels short.',
    imageUrl: '',
    imageObjectKey: '',
    source: 'paperbanana-fallback',
  },
  {
    id: 'paperbanana-style-comparison',
    taskName: 'diagram',
    title: 'Method comparison or ablation diagram',
    summary: 'Use parallel lanes for baseline and proposed method. Highlight the added component with one accent color, keep shared parts grey or muted, and show the final performance/output comparison at the right edge.',
    imageUrl: '',
    imageObjectKey: '',
    source: 'paperbanana-fallback',
  },
]

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
      return ok({ ok: true, runtime: 'laf', version: '0.1.14' })
    }
    if (action === 'createJob') {
      return await createJob(body as CreateJobBody, ctx)
    }
    if (action === 'refineImage') {
      return await refineImage(body as RefineImageBody, ctx)
    }
    if (action === 'prepareReferenceUpload') {
      return await prepareReferenceUpload(body as PrepareReferenceUploadBody)
    }
    if (action === 'modelCapability') {
      return await modelCapability(body as ModelCapabilityBody)
    }
    if (action === 'referenceLibrary') {
      return await referenceLibrary(body as ReferenceLibraryBody)
    }
    if (action === 'getJob') {
      return await getJob((body as GetJobBody).jobId)
    }
    if (action === 'adminJobs') {
      return await adminJobs(body as AdminJobsBody)
    }
    if (action === 'submitFeedback') {
      return await submitFeedback(body as SubmitFeedbackBody, ctx)
    }
    if (action === 'adminFeedback') {
      return await adminFeedback(body as AdminFeedbackBody)
    }
    if (action === 'userJobs') {
      return await userJobs(body as UserJobsBody)
    }
    if (action === 'importReferences') {
      return await importReferences(body as ImportReferencesBody)
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

async function prepareReferenceUpload(body: PrepareReferenceUploadBody) {
  const files = Array.isArray(body.files) ? body.files : []
  if (!files.length) return fail('files is required', 400)
  const originalCount = files.filter((file) => file?.role !== 'analysis').length
  if (originalCount > maxReferenceImages) return fail(`Reference image count exceeds ${maxReferenceImages}`, 400)
  if (files.length > maxReferenceImages * 2) return fail('Too many reference upload files', 400)

  const owner = sanitizePathPart(body.userId || body.userEmail || 'anon')
  const bucket = cloud.storage.bucket(bucketName)
  const uploads = []

  for (const file of files) {
    const descriptor = normalizeUploadDescriptor(file)
    const ext = extensionForMimeType(descriptor.mimeType)
    const role = descriptor.role === 'analysis' ? 'analysis' : 'original'
    const objectKey = `references/${owner}/${randomId()}-${role}.${ext}`
    const expiresAt = Date.now() + referenceUploadTtlSeconds * 1000
    const uploadToken = signReferenceUpload(objectKey, descriptor.mimeType, descriptor.size, expiresAt)
    const uploadResult = await bucket.getUploadUrl(objectKey, referenceUploadTtlSeconds)
    const uploadUrl = typeof uploadResult === 'string'
      ? uploadResult
      : uploadResult?.url || uploadResult?.uploadUrl || uploadResult?.signedUrl || ''

    if (!uploadUrl) throw new Error('Failed to create reference upload URL')
    uploads.push({
      clientId: file.clientId || '',
      role,
      filename: descriptor.filename,
      mimeType: descriptor.mimeType,
      size: descriptor.size,
      objectKey,
      uploadUrl,
      uploadToken,
      expiresAt,
    })
  }

  return ok({ uploads })
}

async function modelCapability(body: ModelCapabilityBody) {
  if (!['openrouter', 'gemini', 'openai', 'bailian'].includes(body.provider)) return fail('Invalid provider', 400)
  if (!body.model) return fail('model is required', 400)
  return ok(await referenceModelCapability(body.provider, normalizeModelName(body.provider, body.model)))
}

async function referenceLibrary(body: ReferenceLibraryBody) {
  const taskName = normalizeTaskName(body.taskName)
  const limit = clamp(Number(body.limit || 24), 1, 60)
  const query = limitText(body.query, 120).toLowerCase()
  const docs = await loadReferenceLibrary(taskName, { limit: Math.max(limit, 24) })
  const filtered = query
    ? docs.filter((item) => [item.title, item.summary, item.id].join(' ').toLowerCase().includes(query))
    : docs
  return ok({ references: filtered.slice(0, limit) })
}

async function createJob(body: CreateJobBody, ctx: FunctionContext) {
  validateCreateBody(body)
  const normalizedBody = {
    ...body,
    taskName: normalizeTaskName(body.taskName),
    infographicCategory: limitText(body.infographicCategory, 80),
    mainModelName: normalizeModelName(body.provider, body.mainModelName),
    imageModelName: normalizeModelName(body.provider, body.imageModelName),
    referenceVisionModelName: normalizeModelName(body.provider, body.referenceVisionModelName || body.mainModelName),
    referenceImageMode: normalizeReferenceImageMode(body.referenceImageMode),
    referenceImages: normalizeReferenceImages(body.referenceImages || []),
    outputFormat: normalizeOutputFormat(body.outputFormat || body.output_format),
    retrievalSetting: normalizeRetrievalSetting(body.retrievalSetting),
    manualReferenceIds: normalizeManualReferenceIds(body.manualReferenceIds || []),
  }
  const apiKey = selectApiKey(normalizedBody.provider, normalizedBody.apiKeys)
  if (!apiKey) {
    return fail(`Missing API key for provider ${normalizedBody.provider}`, 400)
  }

  const modeResolution = await resolveReferenceImageMode(normalizedBody)
  if (modeResolution.error) {
    return fail(modeResolution.error, 400)
  }
  const jobBody = {
    ...normalizedBody,
    referenceImageMode: modeResolution.referenceImageMode,
    referenceImageModeUsed: modeResolution.referenceImageModeUsed,
  }

  const now = new Date()
  const jobId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  const safeNumCandidates = clamp(Number(body.numCandidates || 1), 1, Number(process.env.PAPERBANANA_MAX_CANDIDATES || 3))
  const safeCriticRounds = clamp(Number(body.maxCriticRounds || 1), 0, Number(process.env.PAPERBANANA_MAX_CRITIC_ROUNDS || 2))

  const record = {
    _id: jobId,
    status: 'queued' as JobStatus,
    provider: normalizedBody.provider,
    configurationMode: limitText(normalizedBody.configurationMode, 40) || 'advanced',
    taskName: normalizedBody.taskName,
    userId: normalizedBody.userId || '',
    userEmail: normalizedBody.userEmail || '',
    methodContent: normalizedBody.methodContent,
    caption: normalizedBody.caption,
    infographicCategory: normalizedBody.infographicCategory,
    mainModelName: normalizedBody.mainModelName,
    imageModelName: normalizedBody.imageModelName,
    referenceVisionModelName: normalizedBody.referenceVisionModelName,
    referenceImageMode: jobBody.referenceImageMode,
    referenceImageModeUsed: jobBody.referenceImageModeUsed,
    referenceImages: normalizedBody.referenceImages,
    outputFormat: normalizedBody.outputFormat,
    pipelineMode: normalizedBody.pipelineMode || 'planner_critic',
    retrievalSetting: normalizedBody.retrievalSetting,
    manualReferenceIds: normalizedBody.manualReferenceIds,
    retrievedReferenceIds: [],
    retrievedReferences: [],
    stages: [],
    criticMode: normalizedBody.outputFormat === 'svg' ? 'text' : 'image',
    aspectRatio: normalizedBody.aspectRatio || '16:9',
    numCandidates: safeNumCandidates,
    maxCriticRounds: safeCriticRounds,
    promptCharCount: normalizedBody.methodContent.length + normalizedBody.caption.length,
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
  void runJob(jobId, jobBody, apiKey, safeNumCandidates, safeCriticRounds).catch(async (error) => {
    await markFailed(jobId, error?.message || String(error))
  })

  return ok({ jobId, status: 'queued' })
}

async function refineImage(body: RefineImageBody, ctx: FunctionContext) {
  validateRefineBody(body)
  const normalizedBody = {
    ...body,
    mainModelName: normalizeModelName(body.provider, body.mainModelName || body.imageModelName),
    imageModelName: normalizeModelName(body.provider, body.imageModelName),
    aspectRatio: normalizeAspectRatio(body.aspectRatio),
    imageSize: body.imageSize === '4K' ? '4K' as const : '2K' as const,
  }
  const apiKey = selectApiKey(normalizedBody.provider, normalizedBody.apiKeys)
  if (!apiKey) {
    return fail(`Missing API key for provider ${normalizedBody.provider}`, 400)
  }

  const now = new Date()
  const jobId = `refine-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  const record = {
    _id: jobId,
    status: 'queued' as JobStatus,
    jobType: 'refine',
    provider: normalizedBody.provider,
    configurationMode: 'advanced',
    taskName: 'diagram',
    userId: normalizedBody.userId || '',
    userEmail: normalizedBody.userEmail || '',
    methodContent: normalizedBody.editInstruction,
    caption: 'Refine existing PaperBanana image',
    infographicCategory: '图片精修',
    mainModelName: normalizedBody.mainModelName,
    imageModelName: normalizedBody.imageModelName,
    outputFormat: 'png',
    pipelineMode: 'refine',
    retrievalSetting: 'none',
    manualReferenceIds: [],
    retrievedReferenceIds: [],
    retrievedReferences: [],
    referenceImages: [],
    resultImages: [],
    stages: [],
    criticMode: 'image',
    aspectRatio: normalizedBody.aspectRatio,
    imageSize: normalizedBody.imageSize,
    numCandidates: 1,
    maxCriticRounds: 0,
    promptCharCount: normalizedBody.editInstruction.length,
    sourceImageUrl: limitText(normalizedBody.sourceImageUrl, 1200),
    sourceImageObjectKey: limitText(normalizedBody.sourceImageObjectKey, 300),
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

  void runRefineJob(jobId, normalizedBody, apiKey).catch(async (error) => {
    await markFailed(jobId, error?.message || String(error))
  })

  return ok({ jobId, status: 'queued' })
}

async function getJob(jobId: string) {
  if (!jobId) return fail('jobId is required', 400)
  const job = await jobs.findOne({ _id: jobId })
  if (!job) return fail('Job not found', 404)
  return ok({ job: await publicJob(job) })
}

async function adminJobs(body: AdminJobsBody) {
  const expected = process.env.ADMIN_TOKEN || ''
  if (!expected) return fail('Admin API disabled: ADMIN_TOKEN is not configured', 503)
  if (body.adminToken !== expected) return fail('Invalid admin token', 401)
  const limit = clamp(Number(body.limit || 50), 1, 200)
  const list = await jobs.find({}).sort({ createdAt: -1 }).limit(limit).toArray()
  return ok({ jobs: await Promise.all(list.map(publicJob)) })
}

async function submitFeedback(body: SubmitFeedbackBody, ctx: FunctionContext) {
  const message = String(body.message || '').trim()
  if (!message) return fail('message is required', 400)
  if (message.length > 2000) return fail('message exceeds 2000 characters', 400)

  const platform = normalizeFeedbackPlatform(body.platform)
  if (!platform) return fail('platform is required', 400)

  const clientIp = getClientIp(ctx) || 'unknown'
  const recentSince = new Date(Date.now() - feedbackRateLimitWindowMs)
  const recent = await feedback.find({ clientIp, createdAt: { $gte: recentSince } }).limit(feedbackRateLimitMax).toArray()
  if (recent.length >= feedbackRateLimitMax) {
    return fail('Feedback rate limit exceeded. Please try again later.', 429)
  }

  const now = new Date()
  const id = `feedback-${randomId()}`
  const record = {
    _id: id,
    message,
    category: normalizeFeedbackCategory(body.category),
    jobId: limitText(body.jobId, 120),
    platform,
    clientVersion: limitText(body.clientVersion, 80),
    contact: limitText(body.contact, 300),
    userId: limitText(body.userId, 120),
    userEmail: limitText(body.userEmail, 160),
    clientIp,
    userAgent: limitText(ctx.headers?.['user-agent'], 300),
    status: 'new',
    createdAt: now,
  }

  await feedback.insertOne(record)
  return ok({ ok: true, id })
}

async function adminFeedback(body: AdminFeedbackBody) {
  const expected = process.env.ADMIN_TOKEN || ''
  if (!expected) return fail('Admin API disabled: ADMIN_TOKEN is not configured', 503)
  if (body.adminToken !== expected) return fail('Invalid admin token', 401)
  const limit = clamp(Number(body.limit || 50), 1, 200)
  const status = limitText(body.status, 32)
  const query = status && status !== 'all' ? { status } : {}
  const list = await feedback.find(query).sort({ createdAt: -1 }).limit(limit).toArray()
  return ok({ feedback: list.map(publicFeedback) })
}

async function userJobs(body: UserJobsBody) {
  const userId = body.userId?.trim() || ''
  const userEmail = body.userEmail?.trim() || ''
  if (!userId && !userEmail) return fail('userId is required', 400)
  const limit = clamp(Number(body.limit || 50), 1, 200)
  const query = userId
    ? { $or: [{ userId }, { user_id: userId }] }
    : { $or: [{ userEmail }, { user_email: userEmail }] }
  const list = await jobs.find(query).sort({ createdAt: -1 }).limit(limit).toArray()
  return ok({ jobs: await Promise.all(list.map(publicJob)) })
}

async function resolveReferenceImageMode(body: CreateJobBody & { referenceImageMode: ReferenceImageMode }) {
  const requestedMode = body.referenceImageMode
  const hasReferences = Boolean((body.referenceImages || []).length)
  if (!hasReferences) {
    return {
      referenceImageMode: requestedMode,
      referenceImageModeUsed: 'none' as ReferenceImageModeUsed,
    }
  }

  if (requestedMode === 'vision_model') {
    return {
      referenceImageMode: requestedMode,
      referenceImageModeUsed: 'vision_model' as ReferenceImageModeUsed,
    }
  }

  const capability = await referenceModelCapability(body.provider, body.mainModelName)
  if (requestedMode === 'auto') {
    return {
      referenceImageMode: requestedMode,
      referenceImageModeUsed: capability.status === 'supported' ? 'main_model' as const : 'vision_model' as const,
      capability,
    }
  }

  if (capability.status === 'unsupported') {
    return {
      referenceImageMode: requestedMode,
      referenceImageModeUsed: 'vision_model' as ReferenceImageModeUsed,
      capability,
      error: `当前主模型不支持直接理解参考图，请改用独立识别模型或更换主模型。${capability.reason ? `（${capability.reason}）` : ''}`,
    }
  }

  return {
    referenceImageMode: requestedMode,
    referenceImageModeUsed: 'main_model' as ReferenceImageModeUsed,
    capability,
  }
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

  const retrievedReferences = await resolveRetrievedReferences(body, apiKey)
  await jobs.updateOne(
    { _id: jobId },
    {
      $set: {
        retrievedReferenceIds: retrievedReferences.map((item) => item.id),
        retrievedReferences,
        updatedAt: new Date(),
      },
    },
  )
  if (retrievedReferences.length) {
    await appendLog(jobId, `Retrieved ${retrievedReferences.length} PaperBanana reference example${retrievedReferences.length > 1 ? 's' : ''}`)
  }

  let referenceAnalysis = ''
  let uploadedVisionInputs: VisionImageInput[] = []

  if ((body.referenceImages || []).length) {
    if (body.referenceImageModeUsed === 'main_model') {
      await appendLog(jobId, 'Reference mode: main model direct')
      uploadedVisionInputs = await buildVisionImageInputs(body.referenceImages || [], jobId)
    } else {
      await appendLog(jobId, 'Reference mode: independent vision model')
      referenceAnalysis = await analyzeReferenceImages(jobId, body, apiKey)
    }
  }

  const retrievalContext = buildRetrievalContext(retrievedReferences)
  const retrievedVisionInputs = await buildRetrievedVisionInputs(retrievedReferences)
  const referenceVisionInputs = [...uploadedVisionInputs, ...retrievedVisionInputs]
  const results: any[] = []
  const candidateIndexes = Array.from({ length: numCandidates }, (_, index) => index)
  const concurrency = clamp(Number(process.env.PAPERBANANA_CANDIDATE_CONCURRENCY || 1), 1, numCandidates)
  await runWithConcurrency(candidateIndexes, concurrency, async (i) => {
    const candidateNo = i + 1
    await appendLog(jobId, `Candidate ${candidateNo}: planning`)
    const result = await runCandidate(jobId, i, body, apiKey, maxCriticRounds, referenceAnalysis, retrievalContext, referenceVisionInputs, async (message) => {
      await appendLog(jobId, `Candidate ${candidateNo}: ${message}`)
    })
    await appendLog(jobId, `Candidate ${candidateNo}: saving result`)
    const saved = await saveResult(jobId, i, result.content, result.mimeType, result.encoding)
    results[i] = {
      candidateId: i,
      filename: saved.filename,
      url: saved.url,
      storage: saved.storage,
      mimeType: result.mimeType,
      description: result.description,
    }
  })

  await jobs.updateOne(
    { _id: jobId },
    {
      $set: {
        status: 'succeeded',
        resultImages: results.filter(Boolean),
        referenceAnalysis,
        completedAt: new Date(),
        updatedAt: new Date(),
      },
    },
  )
}

async function runCandidate(
  jobId: string,
  candidateId: number,
  body: CreateJobBody,
  apiKey: string,
  maxCriticRounds: number,
  referenceAnalysis = '',
  retrievalContext = '',
  referenceImages: VisionImageInput[] = [],
  logStage: (message: string) => Promise<void> = async () => {},
) {
  if (normalizeOutputFormat(body.outputFormat) === 'svg') {
    const description = await buildVisualDescription(jobId, candidateId, body, apiKey, maxCriticRounds, referenceAnalysis, retrievalContext, referenceImages, true)
    await logStage('plan ready')
    await logStage('rendering SVG')
    const svgRenderStartedAt = new Date()
    const svg = await callSvgModel(body.provider, body.mainModelName, apiKey, description)
    const stageImage = await saveStageImage(jobId, candidateId, 'svg-final', svg, 'image/svg+xml', 'utf8')
    await recordStage(jobId, {
      candidateId,
      type: 'render',
      title: 'SVG render',
      text: 'Final SVG rendered from the current visual description.',
      image: stageImage,
      startedAt: svgRenderStartedAt,
      completedAt: new Date(),
    })
    return { content: svg, encoding: 'utf8' as const, mimeType: 'image/svg+xml', description }
  }

  if ((body.pipelineMode || 'planner_critic') === 'vanilla') {
    const prompt = diagramPrompt(body.methodContent, body.caption, referenceAnalysis, retrievalContext)
    await recordStage(jobId, {
      candidateId,
      type: 'planner',
      title: 'Vanilla prompt',
      text: prompt,
    })
    await logStage('rendering PNG')
    const vanillaRenderStartedAt = new Date()
    const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, prompt, body.aspectRatio || '16:9')
    const stageImage = await saveStageImage(jobId, candidateId, 'vanilla-render', base64, 'image/png', 'base64')
    await recordStage(jobId, {
      candidateId,
      type: 'render',
      title: 'Vanilla render',
      text: 'Initial image rendered without planner/stylist pipeline.',
      image: stageImage,
      startedAt: vanillaRenderStartedAt,
      completedAt: new Date(),
    })
    return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description: prompt }
  }

  let description = await buildVisualDescription(jobId, candidateId, body, apiKey, 0, referenceAnalysis, retrievalContext, referenceImages, false)
  await logStage('plan ready')
  let imagePrompt = diagramPromptFromDescription(description)
  await logStage('rendering PNG')
  const initialRenderStartedAt = new Date()
  let base64 = await callImageModel(body.provider, body.imageModelName, apiKey, imagePrompt, body.aspectRatio || '16:9')
  let stageImage = await saveStageImage(jobId, candidateId, 'render-0', base64, 'image/png', 'base64')
  await recordStage(jobId, {
    candidateId,
    type: 'render',
    title: 'Initial render',
    text: imagePrompt,
    image: stageImage,
    startedAt: initialRenderStartedAt,
    completedAt: new Date(),
  })

  // Track the last image+description that rendered successfully so we can roll
  // back if a critic re-render throws (mirrors paperviz_processor.py rollback).
  let lastGoodImage = base64
  let lastGoodDescription = description

  for (let round = 1; round <= maxCriticRounds; round += 1) {
    await logStage(`critic round ${round}`)
    const criticStartedAt = new Date()
    const critique = await critiqueRenderedDiagram(body, apiKey, description, base64, referenceAnalysis, retrievalContext)
    const decision = criticDecision(critique, description)
    const noChanges = decision.noChanges
    await recordStage(jobId, {
      candidateId,
      type: 'critic',
      title: `Image critic round ${round}`,
      round,
      text: critique,
      suggestion: noChanges ? '' : critique,
      image: stageImage,
      startedAt: criticStartedAt,
      completedAt: new Date(),
    })
    if (noChanges) break

    description = decision.description
    imagePrompt = diagramPromptFromDescription(description)
    await logStage(`rerender round ${round}`)
    const rerenderStartedAt = new Date()
    try {
      base64 = await callImageModel(body.provider, body.imageModelName, apiKey, imagePrompt, body.aspectRatio || '16:9')
      stageImage = await saveStageImage(jobId, candidateId, `render-${round}`, base64, 'image/png', 'base64')
      await recordStage(jobId, {
        candidateId,
        type: 'render',
        title: `Rerender round ${round}`,
        round,
        text: imagePrompt,
        image: stageImage,
        startedAt: rerenderStartedAt,
        completedAt: new Date(),
      })
      lastGoodImage = base64
      lastGoodDescription = description
    } catch (error: any) {
      // Re-render failed this round: roll back to the last successful
      // image+description and stop the loop rather than failing the candidate.
      const message = error?.message || String(error)
      await logStage(`rerender round ${round} failed, rolling back: ${message}`)
      await recordStage(jobId, {
        candidateId,
        type: 'render',
        title: `Rerender round ${round} (rolled back)`,
        round,
        text: imagePrompt,
        startedAt: rerenderStartedAt,
        completedAt: new Date(),
        error: message,
      })
      base64 = lastGoodImage
      description = lastGoodDescription
      break
    }
  }

  return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description }
}

async function buildVisualDescription(
  jobId: string,
  candidateId: number,
  body: CreateJobBody,
  apiKey: string,
  textCriticRounds: number,
  referenceAnalysis = '',
  retrievalContext = '',
  referenceImages: VisionImageInput[] = [],
  includeTextCritic = false,
) {
  if ((body.pipelineMode || 'planner_critic') === 'vanilla') {
    return withRetrievalContext(withReferenceAnalysis(
      `Create an academic method diagram for this methodology:\n${body.methodContent}\n\nVisual intent:\n${body.caption}`,
      referenceAnalysis,
    ), retrievalContext)
  }

  const infographicCategory = limitText(body.infographicCategory, 80)
  const plannerStartedAt = new Date()
  const planner = await callTextModel(
    body.provider,
    body.mainModelName,
    apiKey,
    plannerSystemPrompt(),
    plannerUserPrompt(body.methodContent, body.caption, referenceAnalysis, retrievalContext, infographicCategory),
    referenceImages,
  )
  await recordStage(jobId, {
    candidateId,
    type: 'planner',
    title: 'Planner',
    text: planner,
    startedAt: plannerStartedAt,
    completedAt: new Date(),
  })

  let description = planner

  if ((body.pipelineMode || 'planner_critic') === 'full') {
    const stylistStartedAt = new Date()
    description = await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      stylistSystemPrompt(),
      stylistUserPrompt(body.methodContent, body.caption, planner, referenceAnalysis, retrievalContext, infographicCategory),
    )
    await recordStage(jobId, {
      candidateId,
      type: 'stylist',
      title: 'Stylist',
      text: description,
      startedAt: stylistStartedAt,
      completedAt: new Date(),
    })
  }

  if (!includeTextCritic) return description

  for (let round = 1; round <= textCriticRounds; round += 1) {
    const criticStartedAt = new Date()
    const critique = await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      criticSystemPrompt(),
      criticUserPrompt(body.methodContent, body.caption, description, referenceAnalysis, retrievalContext),
    )
    const decision = criticDecision(critique, description)
    const noChanges = decision.noChanges
    await recordStage(jobId, {
      candidateId,
      type: 'critic',
      title: `Text critic round ${round}`,
      round,
      text: critique,
      suggestion: noChanges ? '' : critique,
      startedAt: criticStartedAt,
      completedAt: new Date(),
    })
    if (noChanges) break
    description = decision.description
  }

  return description
}

async function runRefineJob(jobId: string, body: RefineImageBody, apiKey: string) {
  await jobs.updateOne(
    { _id: jobId },
    { $set: { status: 'running', startedAt: new Date(), updatedAt: new Date() } },
  )

  const sourceUrl = await resolveSourceImageUrl(body)
  const sourceImage = {
    filename: 'source-image',
    mimeType: inferMimeTypeFromUrl(sourceUrl),
    url: sourceUrl,
  }

  let base64: string
  let description: string

  if (providerSupportsImageEdit(body.provider)) {
    // True image-to-image: forward the source image bytes directly to the
    // image model so it edits the actual pixels (mirrors polish_agent.py).
    await appendLog(jobId, 'Refine: editing source image (image-to-image)')
    const editPrompt = refineEditPrompt(body.editInstruction, body.imageSize || '2K')
    description = editPrompt
    const renderStartedAt = new Date()
    base64 = await callImageModel(body.provider, body.imageModelName, apiKey, editPrompt, body.aspectRatio || '16:9', sourceUrl)
    const stageImage = await saveStageImage(jobId, 0, 'refine-render', base64, 'image/png', 'base64')
    await recordStage(jobId, {
      candidateId: 0,
      type: 'render',
      title: 'Refined render',
      text: body.editInstruction,
      image: stageImage,
      startedAt: renderStartedAt,
      completedAt: new Date(),
    })
  } else {
    // Fallback for providers without image-edit support: describe the source
    // image, then regenerate from the description.
    await appendLog(jobId, 'Refine: analyzing source image')
    const planStartedAt = new Date()
    description = await callTextModel(
      body.provider,
      body.mainModelName || body.imageModelName,
      apiKey,
      refineSystemPrompt(),
      refineUserPrompt(body.editInstruction, body.imageSize || '2K'),
      [sourceImage],
    )
    await recordStage(jobId, {
      candidateId: 0,
      type: 'planner',
      title: 'Refine plan',
      text: description,
      startedAt: planStartedAt,
      completedAt: new Date(),
    })

    await appendLog(jobId, 'Refine: rendering edited image')
    const renderStartedAt = new Date()
    base64 = await callImageModel(body.provider, body.imageModelName, apiKey, diagramPromptFromDescription(description), body.aspectRatio || '16:9')
    const stageImage = await saveStageImage(jobId, 0, 'refine-render', base64, 'image/png', 'base64')
    await recordStage(jobId, {
      candidateId: 0,
      type: 'render',
      title: 'Refined render',
      text: body.editInstruction,
      image: stageImage,
      startedAt: renderStartedAt,
      completedAt: new Date(),
    })
  }

  const saved = await saveResult(jobId, 0, base64, 'image/png', 'base64')
  await jobs.updateOne(
    { _id: jobId },
    {
      $set: {
        status: 'succeeded',
        resultImages: [{
          candidateId: 0,
          filename: saved.filename,
          url: saved.url,
          storage: saved.storage,
          mimeType: 'image/png',
          description,
        }],
        completedAt: new Date(),
        updatedAt: new Date(),
      },
    },
  )
}

async function resolveRetrievedReferences(body: CreateJobBody, apiKey: string): Promise<RetrievedReference[]> {
  const setting = normalizeRetrievalSetting(body.retrievalSetting)
  if (setting === 'none') return []

  const taskName = normalizeTaskName(body.taskName)
  const library = await loadReferenceLibrary(taskName, { limit: 200 })
  if (!library.length) return []

  if (setting === 'manual') {
    const ids = new Set(normalizeManualReferenceIds(body.manualReferenceIds || []))
    return library.filter((item) => ids.has(item.id)).slice(0, 10)
  }

  if (setting === 'random') {
    return shuffle(library).slice(0, 10)
  }

  const selectedIds = await autoSelectReferenceIds(body, apiKey, library)
  const selected = selectedIds
    .map((id) => library.find((item) => item.id === id))
    .filter(Boolean) as RetrievedReference[]
  // On an empty/garbled auto result, return no references rather than dumping
  // the entire library (which would flood the prompt with irrelevant context).
  return selected.slice(0, 10)
}

async function autoSelectReferenceIds(body: CreateJobBody, apiKey: string, library: RetrievedReference[]) {
  const candidates = library.slice(0, 200).map((item) => ({
    id: item.id,
    title: item.title,
    summary: item.summary.slice(0, 1500),
  }))
  const raw = await callTextModel(
    body.provider,
    body.mainModelName,
    apiKey,
    retrievalSystemPrompt(),
    retrievalUserPrompt(body.methodContent, body.caption, candidates),
  )
  const ids = parseReferenceIds(raw)
  return ids.filter((id: string) => library.some((item: RetrievedReference) => item.id === id)).slice(0, 10)
}

async function loadReferenceLibrary(taskName: TaskName, options: { limit: number }): Promise<RetrievedReference[]> {
  const limit = clamp(Number(options.limit || 24), 1, 200)
  const rows = await references.find({ taskName }).sort({ createdAt: -1, _id: 1 }).limit(limit).toArray()
  const normalizedRows = await Promise.all(rows.map(normalizeStoredReference))
  const fallback = fallbackReferences.filter((item) => item.taskName === taskName)
  const seen = new Set(normalizedRows.map((item) => item.id))
  return [
    ...normalizedRows,
    ...fallback.filter((item) => !seen.has(item.id)),
  ].slice(0, limit)
}

async function normalizeStoredReference(item: any): Promise<RetrievedReference> {
  const imageObjectKey = item.imageObjectKey || item.image_object_key || item.objectKey || ''
  let imageUrl = item.imageUrl || item.image_url || item.url || ''
  if (!imageUrl && imageObjectKey) {
    try {
      imageUrl = await cloud.storage.bucket(bucketName).getDownloadUrl(imageObjectKey, 3600 * 24 * 7)
    } catch {
      imageUrl = ''
    }
  }
  return {
    id: String(item._id || item.id || ''),
    taskName: normalizeTaskName(item.taskName || item.task_name),
    title: limitText(item.title || item.visualIntent || item.caption || item.id, 160),
    summary: limitText(item.summary || item.methodExcerpt || item.content || item.description, 1200),
    imageUrl,
    imageObjectKey,
    source: limitText(item.source, 80) || 'paperbanana-bench',
  }
}

async function buildRetrievedVisionInputs(items: RetrievedReference[]) {
  const inputs: VisionImageInput[] = []
  for (const item of items) {
    let url = item.imageUrl
    if (!url && item.imageObjectKey) {
      try {
        url = await cloud.storage.bucket(bucketName).getDownloadUrl(item.imageObjectKey, 3600)
      } catch {
        url = ''
      }
    }
    if (!url) continue
    inputs.push({
      filename: `${item.id}.png`,
      mimeType: inferMimeTypeFromUrl(url),
      url,
    })
  }
  return inputs
}

function buildRetrievalContext(items: RetrievedReference[]) {
  if (!items.length) return ''
  return items.map((item, index) => [
    `Reference ${index + 1} (${item.id}): ${item.title}`,
    item.summary,
  ].filter(Boolean).join('\n')).join('\n\n')
}

async function critiqueRenderedDiagram(
  body: CreateJobBody,
  apiKey: string,
  description: string,
  imageBase64: string,
  referenceAnalysis = '',
  retrievalContext = '',
) {
  // If the rendered image is missing or effectively empty, degrade to a
  // text-only critique and inject a SYSTEM NOTICE instead of sending an empty
  // image (mirrors critic_agent.py's text-only fallback).
  const hasImage = typeof imageBase64 === 'string' && imageBase64.trim().length > 100
  if (!hasImage) {
    return await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      imageCriticSystemPrompt(),
      [
        '[SYSTEM NOTICE] The diagram image could not be generated based on the current description. Check the description for errors and revise it.',
        '',
        imageCriticUserPrompt(body.methodContent, body.caption, description, referenceAnalysis, retrievalContext),
      ].join('\n'),
    )
  }
  return await callTextModel(
    body.provider,
    body.mainModelName,
    apiKey,
    imageCriticSystemPrompt(),
    imageCriticUserPrompt(body.methodContent, body.caption, description, referenceAnalysis, retrievalContext),
    [{ filename: 'candidate.png', mimeType: 'image/png', url: `data:image/png;base64,${imageBase64}` }],
  )
}

// The critic agents return strict JSON {critic_suggestions, revised_description}
// where revised_description === 'No changes needed.' (or empty) means "stop,
// keep the current description". We parse that contract here while remaining
// backward-compatible with plain-text critic responses.
function isNoChangesSignal(value: string) {
  const trimmed = String(value || '').trim()
  if (!trimmed) return true
  return /^no changes? needed\.?$/i.test(trimmed)
}

function criticDecision(critique: string, previous: string): { noChanges: boolean; description: string } {
  const trimmed = String(critique || '').trim()
  if (!trimmed) return { noChanges: true, description: previous }

  const json = parseJsonObject(trimmed)
  if (json && typeof json === 'object') {
    // Read the revised description under any of the supported key spellings.
    const revisedRaw =
      json.revised_description ?? json.revisedDescription ?? json.description
    if (revisedRaw !== undefined && revisedRaw !== null) {
      const revised = String(revisedRaw)
      // Only the revised_description field carries the stop signal; the
      // critic_suggestions field legitimately holds prose that may mention
      // changes even when the revision is "No changes needed.".
      if (isNoChangesSignal(revised)) return { noChanges: true, description: previous }
      return { noChanges: false, description: revised }
    }
  }

  // Backward-compat: plain-text critic response (no JSON / no revised field).
  if (/no changes needed/i.test(trimmed)) return { noChanges: true, description: previous }
  return { noChanges: false, description: trimmed }
}

function extractRevisedDescription(critique: string, previous: string) {
  return criticDecision(critique, previous).description
}

async function analyzeReferenceImages(jobId: string, body: CreateJobBody, apiKey: string) {
  const references = body.referenceImages || []
  if (!references.length) return ''

  if (!body.referenceVisionModelName) {
    throw new Error('referenceVisionModelName is required when referenceImages are provided')
  }

  await appendLog(jobId, `Analyzing ${references.length} reference image${references.length > 1 ? 's' : ''}`)
  const visionInputs = await buildVisionImageInputs(references, jobId)
  const analysis = await callVisionModel(
    body.provider,
    body.referenceVisionModelName,
    apiKey,
    body.methodContent,
    body.caption,
    visionInputs,
  )

  const trimmed = analysis.trim()
  if (!trimmed) throw new Error('Reference vision model returned empty analysis')
  await jobs.updateOne(
    { _id: jobId },
    { $set: { referenceAnalysis: trimmed, updatedAt: new Date() } },
  )
  return trimmed
}

async function buildVisionImageInputs(referenceImages: ReferenceImageInput[], jobId = '') {
  const bucket = cloud.storage.bucket(bucketName)
  const inputs: VisionImageInput[] = []
  let referencesChanged = false

  for (const image of referenceImages) {
    if (!image.objectKey) throw new Error(`Reference image ${image.filename || ''} is missing objectKey`)
    let objectKey = image.analysisObjectKey || image.objectKey
    let mimeType = image.analysisMimeType || image.mimeType
    let url = ''

    if (image.mimeType === 'image/svg+xml' && !image.analysisObjectKey) {
      const analysis = await rasterizeSvgReferenceImage(bucket, image)
      image.analysisObjectKey = analysis.objectKey
      image.analysisMimeType = analysis.mimeType
      image.analysisSize = analysis.size
      objectKey = analysis.objectKey
      mimeType = analysis.mimeType
      url = analysis.url
      referencesChanged = true
    }

    if (!allowedAnalysisMimeTypes.has(mimeType)) {
      throw new Error('Reference image analysis input must be PNG, JPG, or WebP')
    }
    if (!url) url = await bucket.getDownloadUrl(objectKey, 3600)
    inputs.push({
      filename: image.filename,
      mimeType,
      url,
    })
  }

  if (referencesChanged && jobId) {
    await jobs.updateOne(
      { _id: jobId },
      { $set: { referenceImages, updatedAt: new Date() } },
    )
  }

  return inputs
}

async function rasterizeSvgReferenceImage(bucket: any, image: ReferenceImageInput) {
  const sourceUrl = await bucket.getDownloadUrl(image.objectKey, 3600)
  const svgText = await fetchText(sourceUrl, `SVG reference image ${image.filename || ''} download`)
  const pngBuffer = await rasterizeSvgReferenceToPng(svgText)
  if (!pngBuffer.length) throw new Error('SVG reference image rasterization returned empty PNG')
  if (pngBuffer.length > maxReferenceBytes) throw new Error('SVG reference image rasterized PNG exceeds 5MB limit')

  const analysisObjectKey = analysisObjectKeyForSvg(image.objectKey)
  await bucket.writeFile(analysisObjectKey, pngBuffer, { ContentType: 'image/png' })
  return {
    objectKey: analysisObjectKey,
    mimeType: 'image/png',
    size: pngBuffer.length,
    url: await bucket.getDownloadUrl(analysisObjectKey, 3600),
  }
}

async function rasterizeSvgReferenceToPng(rawSvg: string) {
  const svg = sanitizeReferenceSvg(rawSvg)
  const { Resvg } = await loadResvgWasm()
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: svgReferenceRasterWidth },
  })
  return Buffer.from(resvg.render().asPng())
}

async function loadResvgWasm(): Promise<ResvgWasmModule> {
  if (!resvgWasmPromise) {
    resvgWasmPromise = (async () => {
      const fs = require('fs')
      const resvg = require('@resvg/resvg-wasm') as ResvgWasmModule
      const basePath = process.env.CUSTOM_DEPENDENCY_BASE_PATH || '/tmp/custom_dependency'
      const wasmPath = process.env.RESVG_WASM_PATH || `${basePath}/node_modules/@resvg/resvg-wasm/index_bg.wasm`
      const wasmBytes = fs.readFileSync(wasmPath)
      await resvg.initWasm(wasmBytes)
      return resvg
    })()
  }
  return resvgWasmPromise
}

async function fetchText(url: string, label: string) {
  const response = await fetchWithRetry(url, undefined, label)
  if (!response.ok) throw new Error(`${label} failed: HTTP ${response.status}`)
  const text = await response.text()
  if (!text.trim()) throw new Error(`${label} returned empty content`)
  if (Buffer.byteLength(text, 'utf8') > maxReferenceBytes) throw new Error('SVG reference image exceeds 5MB limit')
  return text
}

function analysisObjectKeyForSvg(objectKey: string) {
  const key = String(objectKey || '')
  return /\.svg$/i.test(key) ? key.replace(/\.svg$/i, '-server-analysis.png') : `${key}-server-analysis.png`
}

async function callVisionModel(
  provider: Provider,
  model: string,
  apiKey: string,
  methodContent: string,
  caption: string,
  images: VisionImageInput[],
): Promise<string> {
  if (!images.length) return ''
  if (provider === 'gemini') {
    return callGeminiVision(model, apiKey, methodContent, caption, images)
  }

  const baseUrl = textApiBaseUrl(provider)
  const actualModel = provider === 'openrouter' ? toOpenRouterModel(model) : model
  const content: any[] = [{ type: 'text', text: referenceVisionUserPrompt(methodContent, caption) }]
  for (const image of images) {
    content.push({ type: 'image_url', image_url: { url: image.url } })
  }

  const response = await fetchWithRetry(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: actualModel,
      messages: [
        { role: 'system', content: referenceVisionSystemPrompt() },
        { role: 'user', content },
      ],
      temperature: 0.2,
    }),
  }, `${provider} vision model ${actualModel}`)
  const data = await parseModelResponse(response)
  return data.choices?.[0]?.message?.content || ''
}

async function callGeminiVision(
  model: string,
  apiKey: string,
  methodContent: string,
  caption: string,
  images: VisionImageInput[],
): Promise<string> {
  const parts: any[] = [{ text: referenceVisionUserPrompt(methodContent, caption) }]
  for (const image of images) {
    parts.push({
      inlineData: {
        mimeType: image.mimeType,
        data: await fetchImageAsBase64(image.url, 'Gemini reference image download'),
      },
    })
  }

  const response = await fetchWithRetry(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: referenceVisionSystemPrompt() }] },
      contents: [{ role: 'user', parts }],
      generationConfig: { temperature: 0.2 },
    }),
  }, `gemini vision model ${model}`)
  const data = await parseModelResponse(response)
  return data.candidates?.[0]?.content?.parts?.map((part: any) => part.text || '').join('') || ''
}

async function callTextModel(
  provider: Provider,
  model: string,
  apiKey: string,
  system: string,
  user: string,
  images: VisionImageInput[] = [],
): Promise<string> {
  if (provider === 'gemini') {
    try {
      return await callGeminiText(model, apiKey, system, user, images)
    } catch (error: any) {
      if (images.length) throw new Error(mainModelReferenceError(provider, model, error))
      throw error
    }
  }
  const baseUrl = textApiBaseUrl(provider)
  const actualModel = provider === 'openrouter' ? toOpenRouterModel(model) : model
  try {
    const response = await fetchWithRetry(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: actualModel,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: chatUserContent(user, images) },
        ],
        temperature: 1,
      }),
    }, `${provider} text model ${actualModel}`)
    const data = await parseModelResponse(response)
    return data.choices?.[0]?.message?.content || ''
  } catch (error: any) {
    if (images.length) throw new Error(mainModelReferenceError(provider, actualModel, error))
    throw error
  }
}

async function callSvgModel(provider: Provider, model: string, apiKey: string, description: string): Promise<string> {
  const rawSvg = await callTextModel(
    provider,
    model,
    apiKey,
    svgSystemPrompt(),
    svgUserPrompt(description),
  )
  return sanitizeSvg(rawSvg)
}

async function callImageModel(
  provider: Provider,
  model: string,
  apiKey: string,
  prompt: string,
  aspectRatio: string,
  sourceImage = '',
): Promise<string> {
  // When a source image is supplied, route to a true image-to-image / edit
  // request for providers that support image input. Otherwise fall back to
  // plain text-to-image generation.
  const source = await normalizeSourceImage(sourceImage)

  if (provider === 'openai') {
    if (source) {
      return callOpenAiImageEdit(model, apiKey, prompt, source)
    }
    const response = await fetchWithRetry('https://api.openai.com/v1/images/generations', {
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
    }, `openai image model ${model}`)
    const data = await parseModelResponse(response)
    return data.data?.[0]?.b64_json
  }

  if (provider === 'gemini') {
    return callGeminiImage(model, apiKey, prompt, aspectRatio, source)
  }

  if (provider === 'bailian') {
    // Bailian image model does not support a conditioned edit here; fall back
    // to the describe-then-regenerate path (source image is ignored).
    return callBailianImage(model, apiKey, prompt, aspectRatio)
  }

  const userContent: any[] = [{ type: 'text', text: prompt }]
  if (source) {
    userContent.push({ type: 'image_url', image_url: { url: source.dataUrl } })
  }
  const response = await fetchWithRetry('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: toOpenRouterModel(model),
      messages: [{ role: 'user', content: userContent }],
      modalities: ['image', 'text'],
      image_config: {
        aspect_ratio: aspectRatio,
        image_size: '1k',
      },
    }),
  }, `openrouter image model ${toOpenRouterModel(model)}`)
  const data = await parseModelResponse(response)
  const message = data.choices?.[0]?.message || {}
  const imageUrl = message.images?.[0]?.image_url?.url || ''
  if (imageUrl.includes(',')) return imageUrl.split(',', 2)[1]
  if (typeof message.content === 'string' && message.content.startsWith('data:image')) {
    return message.content.split(',', 2)[1]
  }
  throw new Error('Image model did not return image data')
}

type NormalizedSourceImage = { base64: string; mimeType: string; dataUrl: string }

// Accepts a data URL, a bare base64 string, or a remote/bucket URL and returns
// a normalized base64 + data URL pair for conditioning image-edit requests.
async function normalizeSourceImage(sourceImage: string): Promise<NormalizedSourceImage | null> {
  const value = String(sourceImage || '').trim()
  if (!value) return null

  const dataMatch = value.match(/^data:([^;,]+);base64,(.*)$/i)
  if (dataMatch) {
    const mimeType = dataMatch[1] || 'image/png'
    const base64 = dataMatch[2] || ''
    if (!base64) return null
    return { base64, mimeType, dataUrl: value }
  }

  if (/^https?:\/\//i.test(value)) {
    const mimeType = inferMimeTypeFromUrl(value)
    const base64 = await fetchImageAsBase64(value, 'Refine source image download')
    if (!base64) return null
    return { base64, mimeType, dataUrl: `data:${mimeType};base64,${base64}` }
  }

  // Treat as a bare base64 payload.
  return { base64: value, mimeType: 'image/png', dataUrl: `data:image/png;base64,${value}` }
}

async function callOpenAiImageEdit(model: string, apiKey: string, prompt: string, source: NormalizedSourceImage): Promise<string> {
  const form = new FormData()
  form.append('model', model)
  form.append('prompt', prompt)
  form.append('size', '1536x1024')
  form.append('quality', 'high')
  const ext = source.mimeType === 'image/jpeg' ? 'jpg' : source.mimeType === 'image/webp' ? 'webp' : 'png'
  const blob = new Blob([Buffer.from(source.base64, 'base64')], { type: source.mimeType })
  form.append('image', blob, `source.${ext}`)

  const response = await fetchWithRetry('https://api.openai.com/v1/images/edits', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: form as any,
  }, `openai image edit model ${model}`)
  const data = await parseModelResponse(response)
  const b64 = data.data?.[0]?.b64_json
  if (!b64) throw new Error('OpenAI image edit did not return image data')
  return b64
}

function textApiBaseUrl(provider: Provider) {
  if (provider === 'openrouter') return 'https://openrouter.ai/api/v1'
  if (provider === 'bailian') return 'https://dashscope.aliyuncs.com/compatible-mode/v1'
  return 'https://api.openai.com/v1'
}

async function callGeminiText(
  model: string,
  apiKey: string,
  system: string,
  user: string,
  images: VisionImageInput[] = [],
): Promise<string> {
  const parts: any[] = [{ text: user }]
  for (const image of images) {
    parts.push({
      inlineData: {
        mimeType: image.mimeType,
        data: await fetchImageAsBase64(image.url, 'Gemini main model reference image download'),
      },
    })
  }

  const response = await fetchWithRetry(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: 'user', parts }],
      generationConfig: { temperature: 1 },
    }),
  }, `gemini text model ${model}`)
  const data = await parseModelResponse(response)
  return data.candidates?.[0]?.content?.parts?.map((part: any) => part.text || '').join('') || ''
}

async function callGeminiImage(model: string, apiKey: string, prompt: string, aspectRatio: string, source: NormalizedSourceImage | null = null): Promise<string> {
  const actualModel = normalizeModelName('gemini', model)
  const parts: any[] = [{ text: prompt }]
  if (source) {
    parts.push({ inlineData: { mimeType: source.mimeType, data: source.base64 } })
  }
  const response = await fetchWithRetry(`https://generativelanguage.googleapis.com/v1/models/${actualModel}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts }],
      generationConfig: {
        responseModalities: ['IMAGE'],
        imageConfig: { aspectRatio, imageSize: '1K' },
      },
    }),
  }, `gemini image model ${actualModel}`)
  const data = await parseModelResponse(response)
  for (const part of data.candidates?.[0]?.content?.parts || []) {
    if (part.inlineData?.data) return part.inlineData.data
    if (part.inline_data?.data) return part.inline_data.data
  }
  throw new Error('Gemini image model did not return image data')
}

async function callBailianImage(model: string, apiKey: string, prompt: string, aspectRatio: string): Promise<string> {
  const response = await fetchWithRetry('https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation', {
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
  }, `bailian image model ${model}`)
  const data = await parseDashScopeResponse(response)
  const imageUrl = extractDashScopeImageUrl(data)
  if (!imageUrl) throw new Error('阿里百炼图片模型没有返回图片地址')
  return await fetchImageAsBase64(imageUrl, 'Bailian generated image download')
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

async function fetchImageAsBase64(url: string, label = 'image download') {
  const response = await fetchWithRetry(url, undefined, label)
  if (!response.ok) throw new Error(`${label} failed: HTTP ${response.status}`)
  const arrayBuffer = await response.arrayBuffer()
  return Buffer.from(arrayBuffer).toString('base64')
}

async function saveResult(
  jobId: string,
  candidateId: number,
  content: string,
  mimeType: string,
  encoding: 'base64' | 'utf8',
) {
  const filename = `${jobId}/candidate-${candidateId}.${resultExtension(mimeType)}`
  const buffer = encoding === 'base64' ? Buffer.from(content, 'base64') : Buffer.from(content, 'utf8')
  const base64 = encoding === 'base64' ? content : buffer.toString('base64')
  try {
    const bucket = cloud.storage.bucket(bucketName)
    await bucket.writeFile(filename, buffer, { ContentType: mimeType })
    return {
      storage: 'bucket',
      filename,
      url: await bucket.getDownloadUrl(filename, 3600 * 24 * 7),
    }
  } catch (error: any) {
    return {
      storage: 'database-data-url',
      filename,
      url: `data:${mimeType};base64,${base64}`,
      storageError: error?.message || String(error),
    }
  }
}

async function saveStageImage(
  jobId: string,
  candidateId: number,
  stageName: string,
  content: string,
  mimeType: string,
  encoding: 'base64' | 'utf8',
) {
  const safeStageName = sanitizePathPart(stageName)
  const filename = `${jobId}/candidate-${candidateId}-${safeStageName}.${resultExtension(mimeType)}`
  const buffer = encoding === 'base64' ? Buffer.from(content, 'base64') : Buffer.from(content, 'utf8')
  const base64 = encoding === 'base64' ? content : buffer.toString('base64')
  try {
    const bucket = cloud.storage.bucket(bucketName)
    await bucket.writeFile(filename, buffer, { ContentType: mimeType })
    return {
      storage: 'bucket',
      filename,
      url: await bucket.getDownloadUrl(filename, 3600 * 24 * 7),
      mimeType,
    }
  } catch (error: any) {
    return {
      storage: 'database-data-url',
      filename,
      url: `data:${mimeType};base64,${base64}`,
      mimeType,
      storageError: error?.message || String(error),
    }
  }
}

function resultExtension(mimeType: string) {
  if (mimeType === 'image/svg+xml') return 'svg'
  if (mimeType === 'image/webp') return 'webp'
  if (mimeType === 'image/jpeg') return 'jpg'
  return 'png'
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

async function recordStage(jobId: string, input: Partial<JobStage> & { candidateId: number; type: string; title: string }) {
  const now = new Date()
  const startedAt = input.startedAt || now
  const completedAt = input.completedAt || now
  const stage = {
    id: input.id || `stage-${randomId()}`,
    candidateId: Number(input.candidateId || 0),
    type: input.type,
    title: input.title,
    round: Number(input.round || 0),
    text: limitText(input.text, 12000),
    suggestion: limitText(input.suggestion, 6000),
    image: input.image || null,
    startedAt,
    completedAt,
    durationMs: Number(input.durationMs || (completedAt.getTime() - startedAt.getTime())),
    error: limitText(input.error, 1200),
  }
  await jobs.updateOne(
    { _id: jobId },
    {
      $set: { updatedAt: new Date() },
      $push: { stages: stage },
    },
  )
  return stage
}

async function runWithConcurrency<T>(items: T[], concurrency: number, worker: (item: T) => Promise<void>) {
  let index = 0
  const workers = Array.from({ length: Math.max(1, concurrency) }, async () => {
    while (index < items.length) {
      const current = items[index]
      index += 1
      await worker(current)
    }
  })
  await Promise.all(workers)
}

async function fetchWithRetry(url: string, options: RequestInit | undefined, label: string, attempts = 2) {
  let lastError: any
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await fetch(url, options)
    } catch (error: any) {
      lastError = error
      if (attempt < attempts) {
        await sleep(800 * attempt)
      }
    }
  }
  throw new Error(`${label} request failed: ${lastError?.message || String(lastError)}`)
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function chatUserContent(user: string, images: VisionImageInput[]) {
  if (!images.length) return user
  return [
    { type: 'text', text: user },
    ...images.map((image) => ({
      type: 'image_url',
      image_url: { url: image.url },
    })),
  ]
}

function mainModelReferenceError(provider: Provider, model: string, error: any) {
  const message = error?.message || String(error)
  const hint = '请改用独立识别模型或更换主模型。'
  if (message.includes(hint)) return message
  return `主模型 ${provider}/${model} 直读参考图失败：${message}。${hint}`
}

async function referenceModelCapability(provider: Provider, model: string): Promise<ModelCapabilityResult> {
  const normalizedModel = normalizeModelName(provider, model)
  if (provider === 'bailian') {
    return {
      status: 'unsupported',
      supportsReferenceImages: false,
      reason: '阿里百炼主模型直读参考图本轮暂未启用',
      source: 'paperbanana-static',
      cached: true,
    }
  }

  if (provider === 'openai') {
    const supported = openaiVisionMainModels.has(normalizedModel)
    return {
      status: supported ? 'supported' : 'unknown',
      supportsReferenceImages: supported,
      reason: supported ? 'OpenAI static vision-capable model list' : '模型不在当前 OpenAI 静态白名单内，能力未知',
      source: 'paperbanana-static',
      cached: true,
    }
  }

  if (provider === 'gemini') {
    const supported = geminiVisionMainModels.has(normalizedModel)
    return {
      status: supported ? 'supported' : 'unknown',
      supportsReferenceImages: supported,
      reason: supported ? 'Gemini static vision-capable model list' : '模型不在当前 Gemini 静态白名单内，能力未知',
      source: 'paperbanana-static',
      cached: true,
    }
  }

  return await openRouterReferenceCapability(normalizedModel)
}

async function openRouterReferenceCapability(model: string): Promise<ModelCapabilityResult> {
  const actualModel = toOpenRouterModel(model)
  try {
    const { modalities, cached } = await fetchOpenRouterModelModalities()
    if (!modalities.has(actualModel)) {
      return {
        status: 'unknown',
        supportsReferenceImages: false,
        reason: 'OpenRouter metadata did not include this model id',
        source: 'openrouter-models',
        cached,
      }
    }
    const inputModalities = modalities.get(actualModel) || []
    const supported = inputModalities.includes('image')
    return {
      status: supported ? 'supported' : 'unsupported',
      supportsReferenceImages: supported,
      reason: supported
        ? 'OpenRouter input_modalities includes image'
        : `OpenRouter input_modalities: ${inputModalities.join(', ') || 'none'}`,
      source: 'openrouter-models',
      cached,
    }
  } catch (error: any) {
    return {
      status: 'unknown',
      supportsReferenceImages: false,
      reason: `OpenRouter metadata unavailable: ${error?.message || String(error)}`,
      source: 'openrouter-models',
      cached: false,
    }
  }
}

async function fetchOpenRouterModelModalities() {
  const now = Date.now()
  if (openRouterModelCache && openRouterModelCache.expiresAt > now) {
    return { modalities: openRouterModelCache.modalities, cached: true }
  }

  const response = await fetchWithRetry('https://openrouter.ai/api/v1/models', {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' },
  }, 'OpenRouter model metadata')
  const data = await parseModelResponse(response)
  const modalities = new Map<string, string[]>()
  for (const model of data?.data || []) {
    if (!model?.id) continue
    modalities.set(String(model.id), Array.isArray(model?.architecture?.input_modalities)
      ? model.architecture.input_modalities.map((item: any) => String(item))
      : [])
  }
  openRouterModelCache = {
    expiresAt: now + openRouterModelCacheTtlMs,
    modalities,
  }
  return { modalities, cached: false }
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
    "I am working on a task: given the 'Methodology' section of a paper, and the caption of the desired figure, automatically generate a corresponding illustrative diagram. I will input the text of the 'Methodology' section, the figure caption, and your output should be a detailed description of an illustrative figure that effectively represents the methods described in the text.",
    '',
    'To help you understand the task better, and grasp the principles for generating such figures, I will also provide you with several examples. You should learn from these examples to provide your figure description.',
    '',
    '** IMPORTANT: **',
    'Your description should be as detailed as possible. Semantically, clearly describe each element and their connections. Formally, include various details such as background style (typically pure white or very light pastel), colors, line thickness, icon styles, etc. Remember: vague or unclear specifications will only make the generated figure worse, not better.',
    '',
    'If reference image analysis is provided, use it as structure and style guidance without copying irrelevant content. Do not include the figure title or caption text inside the image.',
  ].join('\n')
}

function plannerUserPrompt(method: string, caption: string, referenceAnalysis = '', retrievalContext = '', infographicCategory = '') {
  return withInfographicCategory(withRetrievalContext(withReferenceAnalysis(
    `Methodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nDetailed description of the target figure:`,
    referenceAnalysis,
  ), retrievalContext), infographicCategory)
}

function stylistSystemPrompt() {
  return [
    '## ROLE',
    'You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).',
    '',
    '## TASK',
    'Our goal is to generate high-quality, publication-ready diagrams, given the methodology section and the caption of the desired diagram. The diagram should illustrate the logic of the methodology section, while adhering to the scope defined by the caption. Before you, a planner agent has already generated a preliminary description of the target diagram. However, this description may lack specific aesthetic details, such as element shapes, color palettes, and background styling. Your task is to refine and enrich this description based on the provided [NeurIPS 2025 Style Guidelines] to ensure the final generated image is a high-quality, publication-ready diagram that adheres to the NeurIPS 2025 aesthetic standards where appropriate.',
    '',
    '## INPUT DATA',
    '-   **Detailed Description**: [The preliminary description of the figure]',
    '-   **Style Guidelines**: [NeurIPS 2025 Style Guidelines]',
    '-   **Methodology Section**: [Contextual content from the methodology section]',
    '-   **Diagram Caption**: [Target diagram caption]',
    '',
    "Note that you should primary focus on the detailed description and style guidelines. The methodology section and diagram caption are provided for context only, there's no need to regenerate a description from scratch, solely based on them, while ignoring the detailed description we already have.",
    '',
    '**Crucial Instructions:**',
    '1.  **Preserve Semantic Content:** Do NOT alter the semantic content, logic, or structure of the diagram. Your job is purely aesthetic refinement, not content editing. However, if you find some phrases or descriptions too verbose, you may simplify them appropriately while referencing the original methodology section to ensure semantic accuracy.',
    '2.  **Preserve High-Quality Aesthetics and Intervene Only When Necessary:** First, evaluate the aesthetic quality implied by the input description. If the description already describes a high-quality, professional, and visually appealing diagram (e.g., nice 3D icons, rich textures, good color harmony), **PRESERVE IT**. Only apply strict Style Guide adjustments if the current description lacks detail, looks outdated, or is visually cluttered. Your goal is specific refinement, not blind standardization.',
    '3.  **Respect Diversity:** Different domains have different styles. If the input describes a specific style (e.g., illustrative for agents) that works well, keep it.',
    '4.  **Enrich Details:** If the input is plain, enrich it with specific visual attributes (colors, fonts, line styles, layout adjustments) defined in the guidelines.',
    '5.  **Handle Icons with Care:** Be cautious when modifying icons as they may carry specific semantic meanings. Some icons have conventional technical meanings (e.g., snowflake = frozen/non-trainable, flame = trainable) - when encountering such icons, reference the original methodology section to verify their intent before making changes. However, purely decorative or symbolic icons can be freely enhanced and beautified. For examples, agent papers often use cute 2D robot avatars to represent agents.',
    '',
    '## OUTPUT',
    'Output ONLY the final polished Detailed Description. Do not include any conversational text or explanations.',
    '',
    '## [NeurIPS 2025 Style Guidelines]',
    neuripsDiagramStyleGuide(),
  ].join('\n')
}

function stylistUserPrompt(method: string, caption: string, description: string, referenceAnalysis = '', retrievalContext = '', infographicCategory = '') {
  return withInfographicCategory(withRetrievalContext(withReferenceAnalysis(
    `Initial Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nPolished detailed description:`,
    referenceAnalysis,
  ), retrievalContext), infographicCategory)
}

function criticSystemPrompt() {
  return diagramCriticSystemPrompt()
}

function diagramCriticSystemPrompt() {
  return [
    '## ROLE',
    'You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).',
    '',
    '## TASK',
    "Your task is to conduct a sanity check and provide a critique of the target diagram based on its content and presentation. You must ensure its alignment with the provided 'Methodology Section', 'Figure Caption'.",
    '',
    "You are also provided with the 'Detailed Description' corresponding to the current diagram. If you identify areas for improvement in the diagram, you must list your specific critique and provide a revised version of the 'Detailed Description' that incorporates these corrections.",
    '',
    '## CRITIQUE & REVISION RULES',
    '',
    '1. Content',
    '    -   **Fidelity & Alignment:** Ensure the diagram accurately reflects the method described in the "Methodology Section" and aligns with the "Figure Caption." Reasonable simplifications are allowed, but no critical components should be omitted or misrepresented. Also, the diagram should not contain any hallucinated content. Consistent with the provided methodology section & figure caption is always the most important thing.',
    '    -   **Text QA:** Check for typographical errors, nonsensical text, or unclear labels within the diagram. Suggest specific corrections.',
    '    -   **Validation of Examples:** Verify the accuracy of illustrative examples. If the diagram includes specific examples to aid understanding (e.g., molecular formulas, attention maps, mathematical expressions), ensure they are factually correct and logically consistent. If an example is incorrect, provide the correct version.',
    '    -   **Caption Exclusion:** Ensure the figure caption text (e.g., "Figure 1: Overview...") is **not** included within the image visual itself. The caption should remain separate.',
    '',
    '2. Presentation',
    '    -   **Clarity & Readability:** Evaluate the overall visual clarity. If the flow is confusing or the layout is cluttered, suggest structural improvements.',
    '    -   **Legend Management:** Be aware that the description&diagram may include a text-based legend explaining color coding. Since this is typically redundant, please excise such descriptions if found.',
    '',
    '** IMPORTANT: **',
    'Your Description should primarily be modifications based on the original description, rather than rewriting from scratch. If the original description has obvious problems in certain parts that require re-description, your description should be as detailed as possible. Semantically, clearly describe each element and their connections. Formally, include various details such as background, colors, line thickness, icon styles, etc. Remember: vague or unclear specifications will only make the generated figure worse, not better.',
    '',
    '## INPUT DATA',
    '-   **Target Diagram**: [The generated figure]',
    '-   **Detailed Description**: [The detailed description of the figure]',
    '-   **Methodology Section**: [Contextual content from the methodology section]',
    '-   **Figure Caption**: [Target figure caption]',
    '',
    '## OUTPUT',
    'Provide your response strictly in the following JSON format.',
    '',
    '```json',
    '{',
    '    "critic_suggestions": "Insert your detailed critique and specific suggestions for improvement here. If the diagram is perfect, write \'No changes needed.\'",',
    '    "revised_description": "Insert the fully revised detailed description here, incorporating all your suggestions. If no changes are needed, write \'No changes needed.\'"',
    '}',
    '```',
  ].join('\n')
}

function criticUserPrompt(method: string, caption: string, description: string, referenceAnalysis = '', retrievalContext = '') {
  return withRetrievalContext(withReferenceAnalysis(
    `Current Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nCritique or revised description:`,
    referenceAnalysis,
  ), retrievalContext)
}

function imageCriticSystemPrompt() {
  // Same rubric and strict JSON contract as the text critic, but a rendered
  // diagram image is attached for inspection.
  return diagramCriticSystemPrompt()
}

function imageCriticUserPrompt(method: string, caption: string, description: string, referenceAnalysis = '', retrievalContext = '') {
  return withRetrievalContext(withReferenceAnalysis(
    `Rendered diagram is attached.\n\nCurrent Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nImage-aware critique or revised description:`,
    referenceAnalysis,
  ), retrievalContext)
}

function diagramPrompt(method: string, caption: string, referenceAnalysis = '', retrievalContext = '') {
  return diagramPromptFromDescription(
    withRetrievalContext(withReferenceAnalysis(
      `Create an academic method diagram for this methodology:\n${method}\n\nVisual intent:\n${caption}`,
      referenceAnalysis,
    ), retrievalContext),
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

function svgSystemPrompt() {
  return [
    'You are the SVG Diagram Agent for PaperBanana.',
    'Return one standalone, valid SVG document only. Do not use Markdown fences.',
    'Use inline SVG elements such as rect, circle, ellipse, path, line, polyline, polygon, text, defs, marker, linearGradient, and g.',
    'Do not use script, style, foreignObject, image, external URLs, event handlers, JavaScript links, or embedded HTML.',
    'Use a clean academic diagram style with readable labels, balanced whitespace, and a light background.',
    'Do not include the figure title or caption text inside the SVG.',
  ].join('\n')
}

function svgUserPrompt(description: string) {
  return [
    'Create an editable SVG academic diagram from this visual specification.',
    'Use viewBox="0 0 1600 900" unless the layout clearly needs another proportional viewBox.',
    'Prefer simple geometric shapes, arrows, concise labels, and semantic grouping.',
    '',
    description,
  ].join('\n')
}

function referenceVisionSystemPrompt() {
  return [
    'You are the Reference Image Analyst for PaperBanana.',
    'Analyze uploaded reference diagrams for reusable academic visual structure and style.',
    'Focus on layout, grouping, arrows, hierarchy, label placement, shape vocabulary, color palette, and visual density.',
    'Do not transcribe private details. Do not ask the generator to copy the reference image pixel-for-pixel.',
  ].join('\n')
}

function referenceVisionUserPrompt(method: string, caption: string) {
  return [
    'Analyze the attached reference image(s) for generating a new academic diagram.',
    'The new figure must be based on the methodology and caption below, not on the reference content itself.',
    '',
    `Methodology Section:\n${method}`,
    '',
    `Figure Caption:\n${caption}`,
    '',
    'Return a concise but detailed reference analysis with these sections:',
    '1. Layout structure to reuse',
    '2. Visual style cues to reuse',
    '3. Elements that should not be copied',
    '4. Practical guidance for an SVG/PNG diagram generator',
  ].join('\n')
}

function retrievalSystemPrompt() {
  return [
    '# Background & Goal',
    'We are building an **AI system to automatically generate method diagrams for academic papers**. Given a paper\'s methodology section and a figure caption, the system needs to create a high-quality illustrative diagram that visualizes the described method.',
    '',
    'To help the AI learn how to generate appropriate diagrams, we use a **few-shot learning approach**: we provide it with reference examples of similar diagrams. The AI will learn from these examples to understand what kind of diagram to create for the target.',
    '',
    '# Your Task',
    '**You are the Retrieval Agent.** Your job is to select the most relevant reference diagrams from a candidate pool that will serve as few-shot examples for the diagram generation model.',
    '',
    'You will receive:',
    '- **Target Input:** The methodology section and caption of the diagram we need to generate',
    '- **Candidate Pool:** Existing diagrams (each with methodology and caption)',
    '',
    'You must select the **Top 10 candidates** that would be most helpful as examples for teaching the AI how to draw the target diagram.',
    '',
    '# Selection Logic (Topic + Intent)',
    '',
    'Your goal is to find examples that match the Target in both **Domain** and **Diagram Type**.',
    '',
    '**1. Match Research Topic (Use Methodology & Caption):**',
    '* What is the domain? (e.g., Agent & Reasoning, Vision & Perception, Generative & Learning, Science & Applications).',
    '* Select candidates that belong to the **same research domain**.',
    '* *Why?* Similar domains share similar terminology (e.g., "Actor-Critic" in RL).',
    '',
    '**2. Match Visual Intent (Use Caption & Keywords):**',
    '* What type of diagram is implied? (e.g., "Framework", "Pipeline", "Detailed Module", "Performance Chart").',
    '* Select candidates with **similar visual structures**.',
    '* *Why?* A "Framework" diagram example is useless for drawing a "Performance Bar Chart", even if they are in the same domain.',
    '',
    '**Ranking Priority:**',
    '1.  **Best Match:** Same Topic AND Same Visual Intent (e.g., Target is "Agent Framework" -> Candidate is "Agent Framework", Target is "Dataset Construction Pipeline" -> Candidate is "Dataset Construction Pipeline").',
    '2.  **Second Best:** Same Visual Intent (e.g., Target is "Agent Framework" -> Candidate is "Vision Framework"). *Structure is more important than Topic for drawing.*',
    '3.  **Avoid:** Different Visual Intent (e.g., Target is "Pipeline" -> Candidate is "Bar Chart").',
    '',
    '# Output Format',
    'Provide your output strictly as a single valid JSON object containing only the **exact IDs** of the Top 10 selected diagrams (use the exact IDs from the Candidate Pool). Select at most 10 ids.',
    'Return JSON only: {"ids":["id-1","id-2"]}.',
  ].join('\n')
}

function retrievalUserPrompt(method: string, caption: string, candidates: any[]) {
  return [
    `Methodology Section:\n${method}`,
    '',
    `Figure Caption:\n${caption}`,
    '',
    'Candidate reference examples:',
    JSON.stringify(candidates),
    '',
    'Choose examples whose layout and visual intent best match the target figure.',
  ].join('\n')
}

// Edit prompt sent directly to an image model that accepts the source image
// as input (true image-to-image conditioned edit).
function refineEditPrompt(instruction: string, imageSize: string) {
  return [
    'You are editing the attached source diagram image directly.',
    'Apply the requested edits to the existing image while preserving everything else: keep the original layout, structure, labels, colors, and style intact except where the instruction requires a change.',
    'Produce a high-quality academic diagram. Do not add a figure title or caption text inside the image.',
    '',
    `Edit instruction:\n${instruction}`,
    '',
    `Target quality: ${imageSize}`,
  ].join('\n')
}

function refineSystemPrompt() {
  return [
    'You are the PaperBanana Refine Agent.',
    'The user provides an existing generated diagram image and an edit instruction.',
    'Inspect the image, preserve its useful structure, and write a complete revised visual description for a new high-quality academic diagram that applies the requested edits.',
    'The next model will render the edited diagram from your description.',
  ].join('\n')
}

function refineUserPrompt(instruction: string, imageSize: string) {
  return [
    'Source image is attached.',
    `Edit instruction:\n${instruction}`,
    '',
    `Target quality: ${imageSize}`,
    '',
    'Return the complete revised visual description only, preserving the parts of the original image not covered by the edit instruction.',
  ].join('\n')
}

function neuripsDiagramStyleGuide() {
  return [
    '### 1. The "NeurIPS Look"',
    'The prevailing aesthetic for 2025 is **"Soft Tech & Scientific Pastels."**',
    'Gone are the days of harsh primary colors and sharp black boxes. The modern NeurIPS diagram feels approachable yet precise. It utilizes high-value (light) backgrounds to organize complexity, reserving saturation for the most critical active elements. The vibe balances **clean modularity** (clear separation of parts) with **narrative flow** (clear left-to-right progression).',
    '',
    '---',
    '',
    '### 2. Detailed Style Options',
    '',
    '#### **A. Color Palettes**',
    '*Design Philosophy: Use color to group logic, not just to decorate. Avoid fully saturated backgrounds.*',
    '',
    '**Background Fills (The "Zone" Strategy)**',
    '*Used to encapsulate stages (e.g., "Pre-training phase") or environments.*',
    '*   **Most papers use:** Very light, desaturated pastels (Opacity ~10–15%).',
    '*   **Aesthetically pleasing options include:**',
    '    *   🍦 **Cream / Beige** (e.g., `#F5F5DC`) – *Warm, academic feel.*',
    '    *   ☁️ **Pale Blue / Ice** (e.g., `#E6F3FF`) – *Clean, technical feel.*',
    '    *   🌿 **Mint / Sage** (e.g., `#E0F2F1`) – *Soft, organic feel.*',
    '    *   🌸 **Pale Lavender** (e.g., `#F3E5F5`) – *distinctive, modern feel.*',
    '*   **Alternative (~20%):** White backgrounds with colored *dashed borders* for a high-contrast, minimalist look (common in theoretical papers).',
    '',
    '**Functional Element Colors**',
    '*   **For "Active" Modules (Encoders, MLP, Attention):** Medium saturation is preferred.',
    '    *   *Common pairings:* Blue/Orange, Green/Purple, or Teal/Pink.',
    '    *   *Observation:* Colors are often used to distinguish **status** rather than component type:',
    '        *   **Trainable Elements:** Often Warm tones (Red, Orange, Deep Pink).',
    '        *   **Frozen/Static Elements:** Often Cool tones (Grey, Ice Blue, Cyan).',
    '*   **For Highlights/Results:** High saturation (Primary Red, Bright Gold) is strictly reserved for "Error/Loss," "Ground Truth," or the final output.',
    '',
    '#### **B. Shapes & Containers**',
    '*Design Philosophy: "Softened Geometry." Sharp corners are for data; rounded corners are for processes.*',
    '',
    '**Core Components**',
    '*   **Process Nodes (The Standard):** Rounded Rectangles (Corner radius 5–10px). This is the dominant shape (~80%) for generic layers or steps.',
    '*   **Tensors & Data:**',
    '    *   **3D Stacks/Cuboids:** Used to imply depth/volume (e.g., $B \\times H \\times W$).',
    '    *   **Flat Squares/Grids:** Used for matrices, tokens, or attention maps.',
    '    *   **Cylinders:** Exclusively reserved for Databases, Buffers, or Memory.',
    '',
    '**Grouping & Hierarchy**',
    '*   **The "Macro-Micro" Pattern:** A solid, light-colored container represents the global view, with a specific module (e.g., "Attention Block") connected via lines to a "zoomed-in" detailed breakout box.',
    '*   **Borders:**',
    '    *   **Solid:** For physical components.',
    '    *   **Dashed:** Highly prevalent for indicating "Logical Stages," "Optional Paths," or "Scopes."',
    '',
    '#### **C. Lines & Arrows**',
    '*Design Philosophy: Line style dictates flow type.*',
    '',
    '**Connector Styles**',
    '*   **Orthogonal / Elbow (Right Angles):** Most papers use this for **Network Architectures** (implies precision, matrices, and tensors).',
    '*   **Curved / Bezier:** Common choices include this for **System Logic, Feedback Loops, or High-Level Data Flow** (implies narrative and connection).',
    '',
    '**Line Semantics**',
    '*   **Solid Black/Grey:** Standard data flow (Forward pass).',
    '*   **Dashed Lines:** Universally recognized as "Auxiliary Flow."',
    '    *   *Used for:* Gradient updates, Skip connections, or Loss calculations.',
    '*   **Integrated Math:** Standard operators ($\\oplus$ for Add, $\\otimes$ for Concat/Multiply) are frequently placed *directly* on the line or intersection.',
    '',
    '#### **D. Typography & Icons**',
    '*Design Philosophy: Strict separation between "Labeling" and "Math."*',
    '',
    '**Typography**',
    '*   **Labels (Module Names):** **Sans-Serif** (Arial, Roboto, Helvetica).',
    '    *   *Style:* Bold for headers, Regular for details.',
    '*   **Variables (Math):** **Serif** (Times New Roman, LaTeX default).',
    '    *   *Rule:* If it is a variable in your equation (e.g., $x, \\theta, \\mathcal{L}$), it **must** be Serif and Italicized in the diagram.',
    '',
    '**Iconography Options**',
    '*   **For Model State:**',
    '    *   *Trainable:* 🔥 Fire, ⚡ Lightning.',
    '    *   *Frozen:* ❄️ Snowflake, 🔒 Padlock, 🛑 Stop Sign (Greyed out).',
    '*   **For Operations:**',
    '    *   *Inspection:* 🔍 Magnifying Glass.',
    '    *   *Processing/Computation:* ⚙️ Gear, 🖥️ Monitor.',
    '*   **For Content:**',
    '    *   *Text/Prompt:* 📄 Document, 💬 Chat Bubble.',
    '    *   *Image:* 🖼️ Actual thumbnail of an image (not just a square).',
    '',
    '---',
    '',
    '### 3. Common Pitfalls (How to look "Amateur")',
    '*   ❌ **The "PowerPoint Default" Look:** Using standard Blue/Orange presets with heavy black outlines.',
    '*   ❌ **Font Mixing:** Using Times New Roman for "Encoder" labels (makes the paper look dated to the 1990s).',
    '*   ❌ **Inconsistent Dimension:** Mixing flat 2D boxes and 3D isometric cubes without a clear reason (e.g., 2D for logic, 3D for tensors is fine; random mixing is not).',
    '*   ❌ **Primary Backgrounds:** Using saturated Yellow or Blue backgrounds for grouping (distracts from the content).',
    '*   ❌ **Ambiguous Arrows:** Using the same line style for "Data Flow" and "Gradient Flow."',
    '',
    '---',
    '',
    '### 4. Domain-Specific Styles',
    '',
    '**If you are writing an AGENT / LLM Paper:**',
    '*   **Vibe:** Illustrative, Narrative, "Friendly.", Cartoony.',
    '*   **Key Elements:** Use "User Interface" aesthetics. Chat bubbles for prompts, document icons for retrieval.',
    "*   **Characters:** It is common to use cute 2D vector robots, human avatars, or emojis to humanize the agent's reasoning steps.",
    '',
    '**If you are writing a COMPUTER VISION / 3D Paper:**',
    '*   **Vibe:** Spatial, Dense, Geometric.',
    '*   **Key Elements:** Frustums (camera cones), Ray lines, and Point Clouds.',
    '*   **Color:** Often uses RGB color coding to denote axes or channel correspondence. Use heatmaps (Rainbow/Viridis) to show activation.',
    '',
    '**If you are writing a THEORETICAL / OPTIMIZATION Paper:**',
    '*   **Vibe:** Minimalist, Abstract, "Textbook."',
    '*   **Key Elements:** Focus on graph nodes (circles) and manifolds (planes/surfaces).',
    '*   **Color:** Restrained. mostly Grayscale/Black/White with one highlight color (e.g., Gold or Blue). Avoid "cartoony" elements.',
  ].join('\n')
}

function neuripsPlotStyleGuide() {
  return [
    '# NeurIPS 2025 Statistical Plot Aesthetics Guide',
    '',
    '## 1. The "NeurIPS Look": A High-Level Overview',
    'The prevailing aesthetic for 2025 is defined by **precision, accessibility, and high contrast**. The "default" academic look has shifted away from bare-bones styling toward a more graphic, publication-ready presentation.',
    '',
    '*   **Vibe:** Professional, clean, and information-dense.',
    '*   **Backgrounds:** There is a heavy bias toward **stark white backgrounds** for maximum contrast in print and PDF reading, though the "Seaborn-style" light grey background remains an accepted variant.',
    '*   **Accessibility:** A strong emphasis on distinguishing data not just by color, but by texture (patterns) and shape (markers) to support black-and-white printing and colorblind readers.',
    '',
    '---',
    '',
    '## 2. Detailed Style Options',
    '',
    '### **Color Palettes**',
    '*   **Categorical Data:**',
    '    *   **Soft Pastels:** Matte, low-saturation colors (salmon, sky blue, mint, lavender) are frequently used to prevent visual fatigue.',
    '    *   **Muted Earth Tones:** "Academic" palettes using olive, beige, slate grey, and navy.',
    '    *   **High-Contrast Primaries:** Used sparingly when categories must be distinct (e.g., deep orange vs. vivid purple).',
    '    *   **Accessibility Mode:** A growing trend involves combining color with **geometric patterns** (hatches, dots, stripes) to differentiate categories.',
    '*   **Sequential & Heatmaps:**',
    '    *   **Perceptually Uniform:** "Viridis" (blue-to-yellow) and "Magma/Plasma" (purple-to-orange) are the standard.',
    '    *   **Diverging:** "Coolwarm" (blue-to-red) is used for positive/negative value splits.',
    '    *   **Avoid:** The traditional "Jet/Rainbow" scale is almost entirely absent.',
    '',
    '### **Axes & Grids**',
    '*   **Grid Style:**',
    '    *   **Visibility:** Grid lines are almost rarely solid. Common choices include **fine dashed (`--`)** or **dotted (`:`)** lines in light gray.',
    '    *   **Placement:** Grids are consistently rendered *behind* data elements (low Z-order).',
    '*   **Spines (Borders):**',
    '    *   **The "Boxed" Look:** A full enclosure (black spines on all 4 sides) is very common.',
    '    *   **The "Open" Look:** Removing the top and right spines for a minimalist appearance.',
    '*   **Ticks:**',
    '    *   **Style:** Ticks are generally subtle, facing inward, or removed entirely in favor of grid alignment.',
    '',
    '### **Layout & Typography**',
    '*   **Typography:**',
    '    *   **Font Family:** Exclusively **Sans-Serif** (resembling Helvetica, Arial, or DejaVu Sans). Serif fonts are rarely used for labels.',
    '    *   **Label Rotation:** X-axis labels are rotated **45 degrees** only when necessary to prevent overlap; otherwise, horizontal orientation is preferred.',
    '*   **Legends:**',
    '    *   **Internal Placement:** Floating the legend *inside* the plot area (top-left or top-right) to maximize the "data-ink ratio."',
    '    *   **Top Horizontal:** Placing the legend in a single row above the plot title.',
    '*   **Annotations:**',
    '    *   **Direct Labeling:** Instead of forcing readers to reference a legend, text is often placed directly next to lines or on top of bars.',
    '',
    '---',
    '',
    '## 3. Type-Specific Guidelines',
    '',
    '### **Bar Charts & Histograms**',
    '*   **Borders:** Two distinct styles are accepted:',
    '    *   **High-Definition:** Using **black outlines** around colored bars for a "comic-book" or high-contrast look.',
    '    *   **Borderless:** Solid color fills with no outline (often used with light grey backgrounds).',
    '*   **Grouping:** Bars are grouped tightly, with significant whitespace between categorical groups.',
    '*   **Error Bars:** Consistently styled with **black, flat caps**.',
    '',
    '### **Line Charts**',
    '*   **Markers:** A critical observation: Lines almost always include **geometric markers** (circles, squares, diamonds) at data points, rather than just being smooth strokes.',
    '*   **Line Styles:** Use **dashed lines** (`--`) for theoretical limits, baselines, or secondary data, and **solid lines** for primary experimental data.',
    '*   **Uncertainty:** Represented by semi-transparent **shaded bands** (confidence intervals) rather than simple vertical error bars.',
    '',
    '### **Tree & Pie/Donut Charts**',
    '*   **Separators:** Thick **white borders** are standard to separate slices or treemap blocks.',
    '*   **Structure:** Thick **Donut charts** are preferred over traditional Pie charts.',
    '*   **Emphasis:** "Exploding" (detaching) a specific slice is a common technique to highlight a key statistic.',
    '',
    '### **Scatter Plots**',
    '*   **Shape Coding:** Use different marker shapes (e.g., circles vs. triangles) to encode a categorical dimension alongside color.',
    '*   **Fills:** Markers are typically solid and fully opaque.',
    '*   **3D Plots:** Depth is emphasized by drawing "walls" with grids or using drop-lines to the "floor" of the plot.',
    '',
    '### **Heatmaps**',
    '*   **Aspect Ratio:** Cells are almost strictly **square**.',
    '*   **Annotation:** Writing the exact value (in white or black text) **inside the cell** is highly preferred over relying solely on a color bar.',
    '*   **Borders:** Cells are often borderless (smooth gradient look) or separated by very thin white lines.',
    '',
    '### **Radar Charts**',
    '*   **Fills:** The polygon area uses **translucent fills** (alpha ~0.2) to show grid lines underneath.',
    '*   **Perimeter:** The outer boundary is marked by a solid, darker line.',
    '',
    '### **Miscellaneous**',
    '*   **Dot Plots:** Used as a modern alternative to bar charts; often styled as "lollipops" (dots connected to the axis by a thin line).',
    '',
    '---',
    '',
    '## 4. Common Pitfalls (What to Avoid)',
    '*   **The "Excel Default" Look:** Avoid heavy 3D effects on bars, shadow drops, or serif fonts (Times New Roman) on axes.',
    '*   **The "Rainbow" Map:** Avoid the Jet/Rainbow colormap; it is considered outdated and perceptually misleading.',
    '*   **Ambiguous Lines:** A line chart *without* markers can look ambiguous if data points are sparse; always add markers.',
    '*   **Over-reliance on Color:** Failing to use patterns or shapes to distinguish groups makes the plot inaccessible to colorblind readers.',
    '*   **Cluttered Grids:** Avoid solid black grid lines; they compete with the data. Always use light grey/dashed grids.',
  ].join('\n')
}

function withReferenceAnalysis(text: string, referenceAnalysis = '') {
  if (!referenceAnalysis.trim()) return text
  return [
    text,
    '',
    'Reference image analysis for structure/style guidance only:',
    referenceAnalysis.trim(),
    '',
    'Use the reference to guide layout and style, but make the final diagram reflect the provided methodology and caption.',
  ].join('\n')
}

function withRetrievalContext(text: string, retrievalContext = '') {
  if (!retrievalContext.trim()) return text
  return [
    text,
    '',
    'Retrieved PaperBanana reference examples for layout/style guidance:',
    retrievalContext.trim(),
    '',
    'Use these examples as high-level few-shot guidance. Do not copy their scientific content unless it matches the provided methodology.',
  ].join('\n')
}

function withInfographicCategory(text: string, infographicCategory = '') {
  const category = String(infographicCategory || '').trim()
  if (!category) return text
  return [
    text,
    '',
    `Infographic category: ${category} — emphasize the conventions of this figure type.`,
  ].join('\n')
}

function sanitizeSvg(raw: string) {
  return sanitizeSvgMarkup(raw, false, 'SVG output')
}

function sanitizeReferenceSvg(raw: string) {
  return sanitizeSvgMarkup(raw, true, 'SVG reference image')
}

function sanitizeSvgMarkup(raw: string, allowImageElement: boolean, label: string) {
  let svg = extractSvg(raw)
    .replace(/<\?xml[\s\S]*?\?>/gi, '')
    .replace(/<!doctype[\s\S]*?>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .trim()

  if (!/^<svg[\s>]/i.test(svg)) {
    throw new Error(`${label} did not contain a valid <svg> root`)
  }

  const forbiddenElement = allowImageElement
    ? /<(script|foreignObject|iframe|object|embed|link|meta|base|audio|video|canvas)\b/i
    : /<(script|foreignObject|iframe|object|embed|link|meta|base|audio|video|canvas|image)\b/i
  if (forbiddenElement.test(svg)) {
    throw new Error(`${label} contained unsupported unsafe elements`)
  }

  const styleBlocks = [...svg.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)].map((match) => match[1] || '')
  const unsafeStylePattern = /(@import|javascript:|url\s*\(\s*['"]?\s*(?:https?:|data:|file:|javascript:))/i
  if (styleBlocks.some((style) => unsafeStylePattern.test(style))) {
    throw new Error(`${label} contained unsupported unsafe style references`)
  }

  const unsafePattern = /(on[a-z]+\s*=|javascript:|data:text\/html|@import|url\s*\(\s*['"]?\s*(?:https?:|data:|file:|javascript:)|href\s*=\s*['"]?\s*(?:https?:|data:|file:|javascript:)|xlink:href\s*=\s*['"]?\s*(?:https?:|data:|file:|javascript:))/i
  if (unsafePattern.test(svg)) {
    throw new Error(`${label} contained unsupported unsafe references`)
  }

  svg = svg.replace(/\s+xmlns:xlink=(["'])[^"']*\1/gi, '')
  if (!/\sxmlns=/.test(svg)) {
    svg = svg.replace(/^<svg/i, '<svg xmlns="http://www.w3.org/2000/svg"')
  }
  return svg
}

function extractSvg(raw: string) {
  const text = String(raw || '')
    .trim()
    .replace(/^```(?:svg|xml)?\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim()
  const start = text.search(/<svg[\s>]/i)
  const end = text.toLowerCase().lastIndexOf('</svg>')
  if (start < 0 || end < 0) {
    throw new Error('SVG model did not return SVG markup')
  }
  return text.slice(start, end + '</svg>'.length)
}

function normalizeUploadDescriptor(file: ReferenceUploadDescriptor) {
  const filename = sanitizeFilename(file?.filename || 'reference')
  const mimeType = normalizeReferenceMimeType(file?.mimeType, filename)
  const size = Number(file?.size || 0)
  const isAnalysis = file?.role === 'analysis'
  const allowed = isAnalysis ? allowedAnalysisMimeTypes : allowedReferenceMimeTypes
  if (!allowed.has(mimeType)) throw new Error(`Unsupported reference image type: ${mimeType || 'unknown'}`)
  if (!size || size < 1) throw new Error('Reference image size is required')
  if (size > maxReferenceBytes) throw new Error('Reference image exceeds 5MB limit')
  return {
    filename,
    mimeType,
    size,
    role: isAnalysis ? 'analysis' as const : 'original' as const,
  }
}

function normalizeReferenceImages(images: ReferenceImageInput[]): StoredReferenceImage[] {
  if (!Array.isArray(images) || !images.length) return []
  if (images.length > maxReferenceImages) throw new Error(`Reference image count exceeds ${maxReferenceImages}`)

  return images.map((image) => {
    const filename = sanitizeFilename(image.filename || 'reference')
    const mimeType = normalizeReferenceMimeType(image.mimeType, filename)
    const size = Number(image.size || 0)
    validateReferenceFileMeta(mimeType, size, allowedReferenceMimeTypes)
    validateObjectKey(image.objectKey)
    verifyReferenceUploadToken(image.objectKey, mimeType, size, image.uploadToken || '')

    const normalized: StoredReferenceImage = {
      filename,
      mimeType,
      size,
      objectKey: image.objectKey,
      storage: 'bucket',
    }

    if (image.analysisObjectKey || image.analysisMimeType || image.analysisUploadToken) {
      const analysisMimeType = normalizeReferenceMimeType(image.analysisMimeType || '', image.analysisObjectKey || 'analysis.png')
      const analysisSize = Number(image.analysisSize || 0)
      validateReferenceFileMeta(analysisMimeType, analysisSize, allowedAnalysisMimeTypes)
      validateObjectKey(image.analysisObjectKey || '')
      verifyReferenceUploadToken(image.analysisObjectKey || '', analysisMimeType, analysisSize, image.analysisUploadToken || '')
      normalized.analysisObjectKey = image.analysisObjectKey
      normalized.analysisMimeType = analysisMimeType
      normalized.analysisSize = analysisSize
    }

    return normalized
  })
}

function validateReferenceFileMeta(mimeType: string, size: number, allowedTypes: Set<string>) {
  if (!allowedTypes.has(mimeType)) throw new Error(`Unsupported reference image type: ${mimeType || 'unknown'}`)
  if (!size || size < 1) throw new Error('Reference image size is required')
  if (size > maxReferenceBytes) throw new Error('Reference image exceeds 5MB limit')
}

function signReferenceUpload(objectKey: string, mimeType: string, size: number, expiresAt: number) {
  const signature = referenceUploadSignature(objectKey, mimeType, size, expiresAt)
  return `v1.${expiresAt}.${signature}`
}

function verifyReferenceUploadToken(objectKey: string, mimeType: string, size: number, token: string) {
  const [version, expiresAtRaw, signature] = String(token || '').split('.')
  const expiresAt = Number(expiresAtRaw)
  if (version !== 'v1' || !expiresAt || !signature) throw new Error('Invalid reference upload token')
  if (Date.now() > expiresAt) throw new Error('Reference upload token expired')
  const expected = referenceUploadSignature(objectKey, mimeType, size, expiresAt)
  if (!safeEqual(signature, expected)) throw new Error('Invalid reference upload token')
}

function referenceUploadSignature(objectKey: string, mimeType: string, size: number, expiresAt: number) {
  return crypto
    .createHmac('sha256', referenceUploadSecret())
    .update([objectKey, mimeType, String(size), String(expiresAt)].join('\n'))
    .digest('hex')
}

function referenceUploadSecret() {
  return process.env.REFERENCE_UPLOAD_TOKEN_SECRET || process.env.ADMIN_TOKEN || 'paperbanana-reference-upload-dev-secret'
}

function safeEqual(left: string, right: string) {
  const leftBuffer = Buffer.from(left)
  const rightBuffer = Buffer.from(right)
  if (leftBuffer.length !== rightBuffer.length) return false
  return crypto.timingSafeEqual(leftBuffer, rightBuffer)
}

function validateObjectKey(objectKey: string) {
  if (!/^references\/[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+\.(png|jpg|jpeg|webp|svg)$/i.test(objectKey || '')) {
    throw new Error('Invalid reference object key')
  }
}

function normalizeReferenceMimeType(mimeType: string, filename = '') {
  const normalized = String(mimeType || '').toLowerCase().split(';', 1)[0].trim()
  if (normalized === 'image/jpg') return 'image/jpeg'
  if (normalized) return normalized
  const lower = filename.toLowerCase()
  if (lower.endsWith('.png')) return 'image/png'
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg'
  if (lower.endsWith('.webp')) return 'image/webp'
  if (lower.endsWith('.svg')) return 'image/svg+xml'
  return ''
}

function extensionForMimeType(mimeType: string) {
  if (mimeType === 'image/png') return 'png'
  if (mimeType === 'image/jpeg') return 'jpg'
  if (mimeType === 'image/webp') return 'webp'
  if (mimeType === 'image/svg+xml') return 'svg'
  throw new Error(`Unsupported reference image type: ${mimeType}`)
}

function sanitizeFilename(filename: string) {
  const safe = String(filename || 'reference')
    .split(/[\\/]/)
    .pop()
    ?.replace(/[^\w.\-\u4e00-\u9fa5 ]+/g, '-')
    .replace(/\s+/g, ' ')
    .trim()
  return safe || 'reference'
}

function sanitizePathPart(value: string) {
  return String(value || 'anon').replace(/[^A-Za-z0-9._-]+/g, '-').slice(0, 80) || 'anon'
}

function randomId() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID()
  return `${Date.now()}-${Math.random().toString(36).slice(2, 12)}`
}

function validateCreateBody(body: CreateJobBody) {
  if (!['openrouter', 'gemini', 'openai', 'bailian'].includes(body.provider)) throw new Error('Invalid provider')
  if (body.taskName && body.taskName !== 'diagram') throw new Error('Plot generation is not enabled yet. Please use diagram task.')
  if (!body.methodContent || body.methodContent.trim().length < 20) throw new Error('methodContent is too short')
  if (!body.caption || body.caption.trim().length < 3) throw new Error('caption is required')
  const requestedFormat = body.outputFormat || body.output_format
  if (requestedFormat && !['png', 'svg'].includes(requestedFormat)) throw new Error('Invalid outputFormat')
  if (!body.mainModelName) throw new Error('mainModelName is required')
  if (!body.imageModelName) throw new Error('imageModelName is required')
  if (body.referenceImageMode && !['auto', 'main_model', 'vision_model'].includes(body.referenceImageMode)) throw new Error('Invalid referenceImageMode')
  if (body.retrievalSetting && !allowedRetrievalSettings.has(body.retrievalSetting)) throw new Error('Invalid retrievalSetting')
  if (body.retrievalSetting === 'manual' && !normalizeManualReferenceIds(body.manualReferenceIds || []).length) {
    throw new Error('manualReferenceIds is required when retrievalSetting is manual')
  }
}

function validateRefineBody(body: RefineImageBody) {
  if (!['openrouter', 'gemini', 'openai', 'bailian'].includes(body.provider)) throw new Error('Invalid provider')
  if (!body.imageModelName) throw new Error('imageModelName is required')
  if (!body.sourceImageUrl && !body.sourceImageObjectKey) throw new Error('source image is required')
  const instruction = String(body.editInstruction || '').trim()
  if (instruction.length < 3) throw new Error('editInstruction is required')
  if (instruction.length > 2000) throw new Error('editInstruction exceeds 2000 characters')
}

function selectApiKey(provider: Provider, apiKeys: ApiKeys) {
  if (provider === 'openrouter') return apiKeys?.openrouter?.trim() || ''
  if (provider === 'gemini') return apiKeys?.gemini?.trim() || ''
  if (provider === 'openai') return apiKeys?.openai?.trim() || ''
  if (provider === 'bailian') return apiKeys?.bailian?.trim() || ''
  return ''
}

// Providers whose image model accepts a source image for a conditioned edit
// (true image-to-image). Bailian only supports text-to-image here, so it falls
// back to the describe-then-regenerate path.
function providerSupportsImageEdit(provider: Provider) {
  return provider === 'gemini' || provider === 'openrouter' || provider === 'openai'
}

async function publicJob(job: any) {
  return {
    id: job._id,
    status: job.status,
    provider: job.provider,
    jobType: job.jobType || 'generate',
    userId: job.userId || job.user_id || '',
    userEmail: job.userEmail || job.user_email || '',
    configurationMode: job.configurationMode || 'advanced',
    taskName: job.taskName || 'diagram',
    methodContent: job.methodContent,
    caption: job.caption,
    infographicCategory: job.infographicCategory || '',
    outputFormat: job.outputFormat || 'png',
    mainModelName: job.mainModelName,
    imageModelName: job.imageModelName,
    referenceVisionModelName: job.referenceVisionModelName || '',
    referenceImageMode: job.referenceImageMode || 'vision_model',
    referenceImageModeUsed: job.referenceImageModeUsed || ((job.referenceImages || []).length ? 'vision_model' : 'none'),
    pipelineMode: job.pipelineMode,
    retrievalSetting: job.retrievalSetting || 'none',
    manualReferenceIds: job.manualReferenceIds || [],
    retrievedReferenceIds: job.retrievedReferenceIds || [],
    retrievedReferences: job.retrievedReferences || [],
    stages: await refreshStageImages(job.stages || []),
    criticMode: job.criticMode || '',
    aspectRatio: job.aspectRatio,
    imageSize: job.imageSize || '',
    numCandidates: job.numCandidates,
    maxCriticRounds: job.maxCriticRounds,
    promptCharCount: job.promptCharCount,
    referenceImageCount: (job.referenceImages || []).length,
    referenceImages: await refreshReferenceImageUrls(job.referenceImages || []),
    resultImages: await refreshStoredImageUrls(job.resultImages || []),
    logs: job.logs || [],
    error: job.error || '',
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    startedAt: job.startedAt,
    completedAt: job.completedAt,
  }
}

async function refreshStageImages(stages: any[]) {
  if (!stages.length) return []
  return await Promise.all(stages.map(async (stage) => {
    if (!stage?.image) return stage
    const refreshed = await refreshStoredImageUrls([stage.image])
    return { ...stage, image: refreshed[0] || stage.image }
  }))
}

async function refreshReferenceImageUrls(images: any[]) {
  if (!images.length) return []
  const refreshed = await refreshStoredImageUrls(images)
  const bucket = cloud.storage.bucket(bucketName)
  return await Promise.all(refreshed.map(async (image) => {
    let analysisUrl = image.analysisUrl || ''
    if (image.analysisObjectKey && !String(analysisUrl).startsWith('data:')) {
      try {
        analysisUrl = await bucket.getDownloadUrl(image.analysisObjectKey, 3600 * 24 * 7)
      } catch {
        analysisUrl = ''
      }
    }
    return {
      filename: image.filename || '',
      objectKey: image.objectKey || '',
      url: image.url || '',
      storage: image.storage || 'bucket',
      mimeType: image.mimeType || '',
      size: Number(image.size || 0),
      analysisObjectKey: image.analysisObjectKey || '',
      analysisUrl,
      analysisMimeType: image.analysisMimeType || '',
      analysisSize: Number(image.analysisSize || 0),
    }
  }))
}

async function refreshStoredImageUrls(images: any[]) {
  if (!images.length) return []
  const bucket = cloud.storage.bucket(bucketName)
  return await Promise.all(images.map(async (image) => {
    const objectKey = image?.objectKey || image?.filename
    if (!objectKey || String(image.url || '').startsWith('data:')) return image
    try {
      return {
        ...image,
        url: await bucket.getDownloadUrl(objectKey, 3600 * 24 * 7),
      }
    } catch {
      return image
    }
  }))
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
  if (Array.isArray(forwarded)) return String(forwarded[0] || '').split(',')[0].trim()
  if (forwarded) return String(forwarded).split(',')[0].trim()
  return String(ctx.headers?.['x-real-ip'] || '').split(',')[0].trim()
}

function toOpenRouterModel(model: string) {
  const raw = normalizeModelName('openrouter', model).replace(/^openrouter\//, '')
  if (raw.includes('/')) return raw
  if (raw.startsWith('gemini')) return `google/${raw}`
  return raw
}

function normalizeModelName(provider: string, model: string) {
  if (provider === 'gemini' && model === 'gemini-3.1-flash-image-preview') return 'gemini-3.1-flash-image'
  return model
}

function normalizeOutputFormat(format?: string): OutputFormat {
  return format === 'svg' ? 'svg' : 'png'
}

function normalizeTaskName(taskName?: string): TaskName {
  return taskName === 'plot' ? 'plot' : 'diagram'
}

function normalizeRetrievalSetting(setting?: string): RetrievalSetting {
  return allowedRetrievalSettings.has(setting as RetrievalSetting) ? setting as RetrievalSetting : 'none'
}

function normalizeManualReferenceIds(ids: string[]) {
  if (!Array.isArray(ids)) return []
  return [...new Set(ids.map((id) => limitText(id, 120)).filter(Boolean))].slice(0, 10)
}

function normalizeAspectRatio(aspectRatio?: string): '16:9' | '21:9' | '3:2' | '1:1' {
  if (aspectRatio === '21:9' || aspectRatio === '3:2' || aspectRatio === '1:1') return aspectRatio
  return '16:9'
}

function normalizeReferenceImageMode(mode?: string): ReferenceImageMode {
  if (mode === 'auto' || mode === 'main_model' || mode === 'vision_model') return mode
  return 'vision_model'
}

function normalizeFeedbackCategory(category?: string): FeedbackCategory {
  return allowedFeedbackCategories.has(category as FeedbackCategory) ? category as FeedbackCategory : 'other'
}

function normalizeFeedbackPlatform(platform?: string): FeedbackPlatform | '' {
  return allowedFeedbackPlatforms.has(platform as FeedbackPlatform) ? platform as FeedbackPlatform : ''
}

function limitText(value: any, maxLength: number) {
  return String(value || '').trim().slice(0, maxLength)
}

async function resolveSourceImageUrl(body: RefineImageBody) {
  const direct = limitText(body.sourceImageUrl, 1200)
  if (direct) return direct
  const objectKey = limitText(body.sourceImageObjectKey, 300)
  if (!objectKey) throw new Error('source image is required')
  return await cloud.storage.bucket(bucketName).getDownloadUrl(objectKey, 3600)
}

function inferMimeTypeFromUrl(url: string) {
  const value = String(url || '').toLowerCase()
  const dataMatch = value.match(/^data:([^;,]+)/)
  if (dataMatch?.[1]) return dataMatch[1]
  if (value.includes('.svg')) return 'image/svg+xml'
  if (value.includes('.webp')) return 'image/webp'
  if (value.includes('.jpg') || value.includes('.jpeg')) return 'image/jpeg'
  return 'image/png'
}

function parseReferenceIds(raw: string): string[] {
  const json = parseJsonObject(raw)
  if (Array.isArray(json?.ids)) return json.ids.map((id: any) => String(id)).filter(Boolean)
  if (Array.isArray(json)) return json.map((id: any) => String(id)).filter(Boolean)
  return [...String(raw || '').matchAll(/[A-Za-z0-9][A-Za-z0-9._:-]{2,}/g)].map((match) => match[0])
}

function parseJsonObject(raw: string) {
  const text = String(raw || '').trim().replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim()
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start < 0 || end < start) {
    try {
      return JSON.parse(text)
    } catch {
      return null
    }
  }
  try {
    return JSON.parse(text.slice(start, end + 1))
  } catch {
    return null
  }
}

function shuffle<T>(items: T[]) {
  const copy = [...items]
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copy[i], copy[j]] = [copy[j], copy[i]]
  }
  return copy
}

function publicFeedback(item: any) {
  return {
    _id: item._id,
    id: item._id,
    message: item.message || '',
    category: item.category || 'other',
    jobId: item.jobId || '',
    platform: item.platform || '',
    clientVersion: item.clientVersion || '',
    contact: item.contact || '',
    userId: item.userId || '',
    userEmail: item.userEmail || '',
    clientIp: redactClientIp(item.clientIp || ''),
    userAgent: limitText(item.userAgent, 160),
    status: item.status || 'new',
    createdAt: item.createdAt,
  }
}

function redactClientIp(ip: string) {
  const value = String(ip || '')
  if (!value || value === 'unknown') return value
  if (value.includes(':')) {
    const parts = value.split(':').filter(Boolean)
    if (parts.length <= 2) return `${parts[0] || ''}:*`
    return `${parts.slice(0, 3).join(':')}:*`
  }
  const parts = value.split('.')
  if (parts.length === 4) return `${parts[0]}.${parts[1]}.${parts[2]}.*`
  return value.replace(/.{3}$/, '***')
}

function clamp(value: number, min: number, max: number) {
  if (Number.isNaN(value)) return min
  return Math.max(min, Math.min(value, max))
}

// ---------------------------------------------------------------------------
// Admin-only: seed the reference library from the public PaperBananaBench zip.
// Safe + re-runnable in batches. Loads even when fflate is absent (lazy require).
// ---------------------------------------------------------------------------
async function importReferences(body: ImportReferencesBody) {
  // ADMIN-GATE first, mirroring adminJobs/adminFeedback.
  const expected = process.env.ADMIN_TOKEN || ''
  if (!expected) return fail('Admin API disabled: ADMIN_TOKEN is not configured', 503)
  if (body.adminToken !== expected) return fail('Invalid admin token', 401)

  const zipUrl = limitText(body.zipUrl, 600) || benchZipUrlDefault
  const taskName = normalizeTaskName(body.taskName) // 'diagram' | 'plot', defaults to 'diagram'
  const mode = body.mode === 'probe' || body.mode === 'inspect' ? body.mode : 'import'

  // PROBE: must NOT require fflate. Range GET because HEAD may be unsupported.
  if (mode === 'probe') {
    try {
      const response = await fetch(zipUrl, { method: 'GET', headers: { Range: 'bytes=0-0' } })
      const contentRange = response.headers.get('content-range') || ''
      const contentLength = response.headers.get('content-length') || ''
      let totalBytes = ''
      const rangeMatch = contentRange.match(/\/(\d+)\s*$/)
      if (rangeMatch) totalBytes = rangeMatch[1]
      else if (contentLength) totalBytes = contentLength
      // Drain the tiny range body so the socket can be reused/released.
      try { await response.arrayBuffer() } catch {}
      return ok({
        reachable: response.ok || response.status === 206 || response.status === 200,
        status: response.status,
        contentLength: totalBytes || contentLength || contentRange || null,
        zipUrl,
      })
    } catch (error: any) {
      return ok({ reachable: false, status: 0, contentLength: null, zipUrl, error: error?.message || String(error) })
    }
  }

  // INSPECT + IMPORT both need the unzipped bench. Lazily require fflate.
  let bench: BenchImportCache
  try {
    bench = await ensureBenchImport(zipUrl, taskName)
  } catch (error: any) {
    if (error && error.code === 'MISSING_FFLATE') {
      return fail('Missing dependency fflate: add it in the Sealaf NPM deps panel', 503)
    }
    return fail(`importReferences failed: ${error?.message || String(error)}`, 500)
  }

  const totalRefs = bench.refItems.length

  if (mode === 'inspect') {
    return ok({
      zipBytes: bench.zipBytes,
      entryCount: bench.entryNames.length,
      refCount: totalRefs,
      refDir: bench.refDir,
      sampleEntryNames: bench.entryNames.slice(0, 15),
      sampleRef: bench.refItems[0] || null,
      taskName,
      zipUrl,
    })
  }

  // mode === 'import'
  const offset = Math.max(0, Number(body.offset) || 0)
  const limit = clamp(Number(body.limit || 25), 1, 200)
  const slice = bench.refItems.slice(offset, offset + limit)
  const bucket = cloud.storage.bucket(bucketName)

  let imported = 0
  const skipped: Array<{ index: number; id: string; skipReason: string }> = []

  for (let i = 0; i < slice.length; i++) {
    const absoluteIndex = offset + i
    const item = slice[i] || {}
    const rawId = item.id || item.paper_id || item.uid || item.name || `${taskName}-${absoluteIndex}`
    const id = limitText(rawId, 120)
    try {
      const relImagePath = item.path_to_gt_image || item.image_path || item.gt_image || ''
      if (!relImagePath) {
        skipped.push({ index: absoluteIndex, id, skipReason: 'no path_to_gt_image' })
        continue
      }
      const entryName = resolveZipEntryPath(bench, String(relImagePath))
      const bytes = entryName ? bench.entries[entryName] : undefined
      if (!bytes) {
        skipped.push({ index: absoluteIndex, id, skipReason: `image not found in zip: ${relImagePath}` })
        continue
      }
      const mimeType = mimeTypeForPath(entryName || String(relImagePath))
      const ext = resultExtension(mimeType)
      const imageObjectKey = `references/bench/${sanitizePathPart(taskName)}/${sanitizePathPart(id)}.${ext}`

      // Upload image bytes to the bucket; NEVER store base64 in Mongo.
      await bucket.writeFile(imageObjectKey, Buffer.from(bytes), { ContentType: mimeType })
      let imageUrl = ''
      try {
        imageUrl = await bucket.getDownloadUrl(imageObjectKey, 3600 * 24 * 7)
      } catch {
        imageUrl = ''
      }

      const content = item.content
      const summary = limitText(typeof content === 'string' ? content : JSON.stringify(content ?? ''), 2000)
      const title = limitText(item.visual_intent || id, 160)

      // Idempotent upsert by id so batches/re-runs do not duplicate.
      await references.updateOne(
        { id },
        {
          $set: {
            id,
            title,
            summary,
            imageObjectKey,
            imageUrl,
            mimeType,
            source: 'paperbanana-bench',
            taskName,
            updatedAt: new Date(),
          },
          $setOnInsert: { createdAt: new Date() },
        },
        { upsert: true },
      )
      imported++
    } catch (error: any) {
      skipped.push({ index: absoluteIndex, id, skipReason: error?.message || String(error) })
    }
  }

  const nextOffset = offset + slice.length
  return ok({
    imported,
    skipped,
    totalRefs,
    offset,
    limit,
    nextOffset,
    done: nextOffset >= totalRefs,
    taskName,
    zipUrl,
  })
}

// Ensure the bench zip is downloaded (cached to /tmp + in module memory) and
// the requested task's ref.json is parsed. Lazily requires fflate; throws a
// tagged error (code MISSING_FFLATE) when the dependency is absent.
async function ensureBenchImport(zipUrl: string, taskName: TaskName): Promise<BenchImportCache> {
  // Reuse the in-memory cache when it matches this zip. The zip entries are
  // shared across tasks; only refDir/refItems are task-specific, so re-resolve
  // ref.json from the already-unzipped entries when the task differs.
  if (importCache && importCache.zipUrl === zipUrl && importCache.entryNames.length) {
    if (importCache.refDir.endsWith(`/${taskName}`)) {
      return importCache
    }
    const located = locateRefJson(importCache.entries, importCache.entryNames, taskName)
    importCache.refDir = located.refDir
    importCache.refItems = located.refItems
    return importCache
  }

  const req: any = (globalThis as any).require || (typeof require !== 'undefined' ? require : null)
  if (!req) {
    const err: any = new Error('require unavailable')
    err.code = 'MISSING_FFLATE'
    throw err
  }
  const fs: any = req('fs')

  // Download (or reuse the /tmp cache) the full zip.
  let zipBuffer: Buffer
  if (fs.existsSync(benchZipCachePath) && fs.statSync(benchZipCachePath).size > 0) {
    zipBuffer = fs.readFileSync(benchZipCachePath)
  } else {
    const response = await fetch(zipUrl, { method: 'GET' })
    if (!response.ok) throw new Error(`Failed to download zip: HTTP ${response.status}`)
    const arrayBuffer = await response.arrayBuffer()
    zipBuffer = Buffer.from(arrayBuffer)
    try { fs.writeFileSync(benchZipCachePath, zipBuffer) } catch {}
  }

  // Lazily require fflate ONLY here (inspect/import path), never at module top.
  let unzipSync: (data: Uint8Array) => Record<string, Uint8Array>
  try {
    const fflate = req('fflate')
    unzipSync = fflate.unzipSync
    if (typeof unzipSync !== 'function') throw new Error('unzipSync missing')
  } catch {
    const err: any = new Error('fflate not installed')
    err.code = 'MISSING_FFLATE'
    throw err
  }

  const entries = unzipSync(new Uint8Array(zipBuffer))
  const entryNames = Object.keys(entries)
  const located = locateRefJson(entries, entryNames, taskName)

  importCache = {
    zipUrl,
    zipBytes: zipBuffer.length,
    entries,
    entryNames,
    refDir: located.refDir,
    refItems: located.refItems,
  }
  return importCache
}

// Find the requested task's ref.json (entry path ending /<task>/ref.json),
// parse it into an array, and return both the items and its directory.
function locateRefJson(
  entries: Record<string, Uint8Array>,
  entryNames: string[],
  taskName: TaskName,
): { refDir: string; refItems: any[] } {
  const suffix = `/${taskName}/ref.json`
  let refEntry =
    entryNames.find((name) => name.endsWith(suffix)) ||
    entryNames.find((name) => name.endsWith(`${taskName}/ref.json`)) ||
    entryNames.find((name) => name.toLowerCase().endsWith('/ref.json') && name.toLowerCase().includes(`/${taskName}/`))
  if (!refEntry) {
    return { refDir: '', refItems: [] }
  }
  const refDir = refEntry.slice(0, refEntry.length - '/ref.json'.length).replace(/\/+$/, '')
  let parsed: any
  try {
    const text = Buffer.from(entries[refEntry]).toString('utf8')
    parsed = JSON.parse(text)
  } catch {
    return { refDir, refItems: [] }
  }
  let items: any[] = []
  if (Array.isArray(parsed)) items = parsed
  else if (Array.isArray(parsed?.data)) items = parsed.data
  else if (Array.isArray(parsed?.items)) items = parsed.items
  else if (Array.isArray(parsed?.references)) items = parsed.references
  else if (parsed && typeof parsed === 'object') {
    // Mapping of id -> item; flatten to an array while preserving the key as id.
    items = Object.entries(parsed).map(([key, value]: [string, any]) =>
      value && typeof value === 'object' ? { id: value.id || key, ...value } : { id: key, value })
  }
  return { refDir, refItems: items }
}

// Resolve an image path that is relative to the ref.json directory into a real
// zip entry name. Tries the joined path plus a few normalized fallbacks.
function resolveZipEntryPath(bench: BenchImportCache, relPath: string): string | null {
  const cleaned = String(relPath || '').replace(/^\.\//, '').replace(/^\/+/, '')
  const candidates: string[] = []
  if (bench.refDir) candidates.push(`${bench.refDir}/${cleaned}`)
  candidates.push(cleaned)
  // Collapse any ../ segments against the ref dir.
  if (bench.refDir && cleaned.includes('../')) {
    const dirParts = bench.refDir.split('/')
    const relParts = cleaned.split('/')
    for (const part of relParts) {
      if (part === '..') dirParts.pop()
      else if (part !== '.') dirParts.push(part)
    }
    candidates.push(dirParts.join('/'))
  }
  for (const candidate of candidates) {
    if (bench.entries[candidate]) return candidate
  }
  // Last resort: match by basename suffix.
  const base = cleaned.split('/').pop() || ''
  if (base) {
    const hit = bench.entryNames.find((name) => name.endsWith(`/${base}`) || name === base)
    if (hit) return hit
  }
  return null
}

function mimeTypeForPath(path: string) {
  const value = String(path || '').toLowerCase()
  if (value.endsWith('.svg')) return 'image/svg+xml'
  if (value.endsWith('.webp')) return 'image/webp'
  if (value.endsWith('.jpg') || value.endsWith('.jpeg')) return 'image/jpeg'
  if (value.endsWith('.gif')) return 'image/png' // store gif frames as png-extension safe default
  return 'image/png'
}
