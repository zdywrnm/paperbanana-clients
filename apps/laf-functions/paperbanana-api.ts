import cloud from '@lafjs/cloud'
import * as crypto from 'crypto'

declare const require: any

type Provider = 'openrouter' | 'gemini' | 'openai' | 'bailian'
type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed'
type OutputFormat = 'png' | 'svg'
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
  methodContent: string
  caption: string
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
  aspectRatio?: '16:9' | '21:9' | '3:2' | '1:1'
  numCandidates?: number
  maxCriticRounds?: number
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

type ModelCapabilityBody = {
  action: 'modelCapability'
  provider: Provider
  model: string
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

type RequestBody =
  | CreateJobBody
  | PrepareReferenceUploadBody
  | GetJobBody
  | AdminJobsBody
  | SubmitFeedbackBody
  | AdminFeedbackBody
  | UserJobsBody
  | ModelCapabilityBody
  | HealthBody

const db = cloud.mongo.db
const jobs = db.collection('paperbanana_jobs')
const feedback = db.collection('paperbanana_feedback')
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
let openRouterModelCache: { expiresAt: number; modalities: Map<string, string[]> } | null = null
let resvgWasmPromise: Promise<ResvgWasmModule> | null = null

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
    if (action === 'prepareReferenceUpload') {
      return await prepareReferenceUpload(body as PrepareReferenceUploadBody)
    }
    if (action === 'modelCapability') {
      return await modelCapability(body as ModelCapabilityBody)
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

async function createJob(body: CreateJobBody, ctx: FunctionContext) {
  validateCreateBody(body)
  const normalizedBody = {
    ...body,
    mainModelName: normalizeModelName(body.provider, body.mainModelName),
    imageModelName: normalizeModelName(body.provider, body.imageModelName),
    referenceVisionModelName: normalizeModelName(body.provider, body.referenceVisionModelName || body.mainModelName),
    referenceImageMode: normalizeReferenceImageMode(body.referenceImageMode),
    referenceImages: normalizeReferenceImages(body.referenceImages || []),
    outputFormat: normalizeOutputFormat(body.outputFormat || body.output_format),
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
    userId: normalizedBody.userId || '',
    userEmail: normalizedBody.userEmail || '',
    methodContent: normalizedBody.methodContent,
    caption: normalizedBody.caption,
    mainModelName: normalizedBody.mainModelName,
    imageModelName: normalizedBody.imageModelName,
    referenceVisionModelName: normalizedBody.referenceVisionModelName,
    referenceImageMode: jobBody.referenceImageMode,
    referenceImageModeUsed: jobBody.referenceImageModeUsed,
    referenceImages: normalizedBody.referenceImages,
    outputFormat: normalizedBody.outputFormat,
    pipelineMode: normalizedBody.pipelineMode || 'planner_critic',
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

  let referenceAnalysis = ''
  let sharedPlannerDescription = ''

  if ((body.referenceImages || []).length) {
    if (body.referenceImageModeUsed === 'main_model') {
      await appendLog(jobId, 'Reference mode: main model direct')
      await appendLog(jobId, 'Reference planner: planning with main model')
      const visionInputs = await buildVisionImageInputs(body.referenceImages || [], jobId)
      sharedPlannerDescription = await planDiagramDescription(body, apiKey, maxCriticRounds, '', visionInputs, true)
      await appendLog(jobId, 'Reference planner: plan ready')
    } else {
      await appendLog(jobId, 'Reference mode: independent vision model')
      referenceAnalysis = await analyzeReferenceImages(jobId, body, apiKey)
    }
  }

  const results = []
  for (let i = 0; i < numCandidates; i += 1) {
    const candidateNo = i + 1
    await appendLog(jobId, sharedPlannerDescription ? `Candidate ${candidateNo}: using shared plan` : `Candidate ${candidateNo}: planning`)
    const result = await runCandidate(body, apiKey, maxCriticRounds, referenceAnalysis, sharedPlannerDescription, async (message) => {
      await appendLog(jobId, `Candidate ${candidateNo}: ${message}`)
    })
    await appendLog(jobId, `Candidate ${candidateNo}: saving result`)
    const saved = await saveResult(jobId, i, result.content, result.mimeType, result.encoding)
    results.push({
      candidateId: i,
      filename: saved.filename,
      url: saved.url,
      storage: saved.storage,
      mimeType: result.mimeType,
      description: result.description,
    })
  }

  await jobs.updateOne(
    { _id: jobId },
    {
      $set: {
        status: 'succeeded',
        resultImages: results,
        referenceAnalysis,
        referencePlannerDescription: sharedPlannerDescription,
        completedAt: new Date(),
        updatedAt: new Date(),
      },
    },
  )
}

async function runCandidate(
  body: CreateJobBody,
  apiKey: string,
  maxCriticRounds: number,
  referenceAnalysis = '',
  sharedPlannerDescription = '',
  logStage: (message: string) => Promise<void> = async () => {},
) {
  if (normalizeOutputFormat(body.outputFormat) === 'svg') {
    const description = sharedPlannerDescription || await planDiagramDescription(body, apiKey, maxCriticRounds, referenceAnalysis)
    await logStage('plan ready')
    await logStage('rendering SVG')
    const svg = await callSvgModel(body.provider, body.mainModelName, apiKey, description)
    return { content: svg, encoding: 'utf8' as const, mimeType: 'image/svg+xml', description }
  }

  if ((body.pipelineMode || 'planner_critic') === 'vanilla') {
    if (sharedPlannerDescription) {
      await logStage('plan ready')
      await logStage('rendering PNG')
      const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, diagramPromptFromDescription(sharedPlannerDescription), body.aspectRatio || '16:9')
      return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description: sharedPlannerDescription }
    }
    const prompt = diagramPrompt(body.methodContent, body.caption, referenceAnalysis)
    await logStage('rendering PNG')
    const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, prompt, body.aspectRatio || '16:9')
    return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description: prompt }
  }

  const description = sharedPlannerDescription || await planDiagramDescription(body, apiKey, maxCriticRounds, referenceAnalysis)
  await logStage('plan ready')
  const imagePrompt = diagramPromptFromDescription(description)
  await logStage('rendering PNG')
  const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, imagePrompt, body.aspectRatio || '16:9')
  return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description }
}

async function planDiagramDescription(
  body: CreateJobBody,
  apiKey: string,
  maxCriticRounds: number,
  referenceAnalysis = '',
  referenceImages: VisionImageInput[] = [],
  forcePlanner = false,
) {
  if ((body.pipelineMode || 'planner_critic') === 'vanilla' && !forcePlanner) {
    return withReferenceAnalysis(
      `Create an academic method diagram for this methodology:\n${body.methodContent}\n\nVisual intent:\n${body.caption}`,
      referenceAnalysis,
    )
  }

  const planner = await callTextModel(
    body.provider,
    body.mainModelName,
    apiKey,
    plannerSystemPrompt(),
    plannerUserPrompt(body.methodContent, body.caption, referenceAnalysis),
    referenceImages,
  )

  let description = planner
  if (forcePlanner && (body.pipelineMode || 'planner_critic') === 'vanilla') {
    return description
  }

  if ((body.pipelineMode || 'planner_critic') === 'full') {
    description = await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      stylistSystemPrompt(),
      stylistUserPrompt(body.methodContent, body.caption, planner, referenceAnalysis),
    )
  }

  for (let round = 0; round < maxCriticRounds; round += 1) {
    const critique = await callTextModel(
      body.provider,
      body.mainModelName,
      apiKey,
      criticSystemPrompt(),
      criticUserPrompt(body.methodContent, body.caption, description, referenceAnalysis),
    )
    if (/no changes needed/i.test(critique)) break
    description = critique
  }

  return description
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

async function callImageModel(provider: Provider, model: string, apiKey: string, prompt: string, aspectRatio: string): Promise<string> {
  if (provider === 'openai') {
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
    return callGeminiImage(model, apiKey, prompt, aspectRatio)
  }

  if (provider === 'bailian') {
    return callBailianImage(model, apiKey, prompt, aspectRatio)
  }

  const response = await fetchWithRetry('https://openrouter.ai/api/v1/chat/completions', {
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

async function callGeminiImage(model: string, apiKey: string, prompt: string, aspectRatio: string): Promise<string> {
  const actualModel = normalizeModelName('gemini', model)
  const response = await fetchWithRetry(`https://generativelanguage.googleapis.com/v1/models/${actualModel}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
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
    'You are the Planner Agent for PaperBanana.',
    'Given a paper methodology section and figure caption, write a detailed visual specification for a publication-quality academic diagram.',
    'Describe semantic components, layout, arrows, labels, colors, background, spacing, and icon style.',
    'If reference image analysis is provided, use it as structure and style guidance without copying irrelevant content.',
    'Do not include the figure title or caption text inside the image.',
  ].join('\n')
}

function plannerUserPrompt(method: string, caption: string, referenceAnalysis = '') {
  return withReferenceAnalysis(
    `Methodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nDetailed description of the target figure:`,
    referenceAnalysis,
  )
}

function stylistSystemPrompt() {
  return [
    'You are the Stylist Agent for PaperBanana.',
    'Refine the visual specification for a clean NeurIPS-style academic diagram.',
    'Preserve semantics. Improve layout clarity, typography, color harmony, line thickness, and whitespace.',
    'Use reference image analysis only for layout and style cues.',
  ].join('\n')
}

function stylistUserPrompt(method: string, caption: string, description: string, referenceAnalysis = '') {
  return withReferenceAnalysis(
    `Initial Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nPolished detailed description:`,
    referenceAnalysis,
  )
}

function criticSystemPrompt() {
  return [
    'You are the Critic Agent for PaperBanana.',
    'Check whether the current diagram description matches the methodology and caption.',
    'If changes are needed, return a revised detailed description only.',
    'If it is already good, return exactly: No changes needed.',
  ].join('\n')
}

function criticUserPrompt(method: string, caption: string, description: string, referenceAnalysis = '') {
  return withReferenceAnalysis(
    `Current Description:\n${description}\n\nMethodology Section:\n${method}\n\nFigure Caption:\n${caption}\n\nCritique or revised description:`,
    referenceAnalysis,
  )
}

function diagramPrompt(method: string, caption: string, referenceAnalysis = '') {
  return diagramPromptFromDescription(
    withReferenceAnalysis(
      `Create an academic method diagram for this methodology:\n${method}\n\nVisual intent:\n${caption}`,
      referenceAnalysis,
    ),
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
  if (!body.methodContent || body.methodContent.trim().length < 20) throw new Error('methodContent is too short')
  if (!body.caption || body.caption.trim().length < 3) throw new Error('caption is required')
  const requestedFormat = body.outputFormat || body.output_format
  if (requestedFormat && !['png', 'svg'].includes(requestedFormat)) throw new Error('Invalid outputFormat')
  if (!body.mainModelName) throw new Error('mainModelName is required')
  if (!body.imageModelName) throw new Error('imageModelName is required')
  if (body.referenceImageMode && !['auto', 'main_model', 'vision_model'].includes(body.referenceImageMode)) throw new Error('Invalid referenceImageMode')
}

function selectApiKey(provider: Provider, apiKeys: ApiKeys) {
  if (provider === 'openrouter') return apiKeys?.openrouter?.trim() || ''
  if (provider === 'gemini') return apiKeys?.gemini?.trim() || ''
  if (provider === 'openai') return apiKeys?.openai?.trim() || ''
  if (provider === 'bailian') return apiKeys?.bailian?.trim() || ''
  return ''
}

async function publicJob(job: any) {
  return {
    id: job._id,
    status: job.status,
    provider: job.provider,
    userId: job.userId || job.user_id || '',
    userEmail: job.userEmail || job.user_email || '',
    methodContent: job.methodContent,
    caption: job.caption,
    outputFormat: job.outputFormat || 'png',
    mainModelName: job.mainModelName,
    imageModelName: job.imageModelName,
    referenceVisionModelName: job.referenceVisionModelName || '',
    referenceImageMode: job.referenceImageMode || 'vision_model',
    referenceImageModeUsed: job.referenceImageModeUsed || ((job.referenceImages || []).length ? 'vision_model' : 'none'),
    pipelineMode: job.pipelineMode,
    aspectRatio: job.aspectRatio,
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
