import cloud from '@lafjs/cloud'
import * as crypto from 'crypto'

type Provider = 'openrouter' | 'gemini' | 'openai' | 'bailian'
type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed'
type OutputFormat = 'png' | 'svg'
type ReferenceImageRole = 'original' | 'analysis'

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

type UserJobsBody = {
  action: 'userJobs'
  userId: string
  userEmail?: string
  limit?: number
}

type HealthBody = {
  action: 'health'
}

type RequestBody = CreateJobBody | PrepareReferenceUploadBody | GetJobBody | AdminJobsBody | UserJobsBody | HealthBody

const db = cloud.mongo.db
const jobs = db.collection('paperbanana_jobs')
const bucketName = process.env.PAPERBANANA_BUCKET || 'paperbanana'
const maxReferenceImages = Number(process.env.PAPERBANANA_MAX_REFERENCE_IMAGES || 3)
const maxReferenceBytes = Number(process.env.PAPERBANANA_MAX_REFERENCE_BYTES || 5 * 1024 * 1024)
const referenceUploadTtlSeconds = Number(process.env.PAPERBANANA_REFERENCE_UPLOAD_TTL_SECONDS || 900)
const allowedReferenceMimeTypes = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
const allowedAnalysisMimeTypes = new Set(['image/png', 'image/jpeg', 'image/webp'])

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
      return ok({ ok: true, runtime: 'laf', version: '0.1.11' })
    }
    if (action === 'createJob') {
      return await createJob(body as CreateJobBody, ctx)
    }
    if (action === 'prepareReferenceUpload') {
      return await prepareReferenceUpload(body as PrepareReferenceUploadBody)
    }
    if (action === 'getJob') {
      return await getJob((body as GetJobBody).jobId)
    }
    if (action === 'adminJobs') {
      return await adminJobs(body as AdminJobsBody)
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

async function createJob(body: CreateJobBody, ctx: FunctionContext) {
  validateCreateBody(body)
  const normalizedBody = {
    ...body,
    mainModelName: normalizeModelName(body.provider, body.mainModelName),
    imageModelName: normalizeModelName(body.provider, body.imageModelName),
    referenceVisionModelName: normalizeModelName(body.provider, body.referenceVisionModelName || body.mainModelName),
    referenceImages: normalizeReferenceImages(body.referenceImages || []),
    outputFormat: normalizeOutputFormat(body.outputFormat || body.output_format),
  }
  const apiKey = selectApiKey(normalizedBody.provider, normalizedBody.apiKeys)
  if (!apiKey) {
    return fail(`Missing API key for provider ${normalizedBody.provider}`, 400)
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
  void runJob(jobId, normalizedBody, apiKey, safeNumCandidates, safeCriticRounds).catch(async (error) => {
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

  const referenceAnalysis = await analyzeReferenceImages(jobId, body, apiKey)

  const results = []
  for (let i = 0; i < numCandidates; i += 1) {
    await appendLog(jobId, `Candidate ${i + 1}: planning`)
    const result = await runCandidate(body, apiKey, maxCriticRounds, referenceAnalysis)
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
        completedAt: new Date(),
        updatedAt: new Date(),
      },
    },
  )
}

async function runCandidate(body: CreateJobBody, apiKey: string, maxCriticRounds: number, referenceAnalysis = '') {
  if (normalizeOutputFormat(body.outputFormat) === 'svg') {
    const description = await planDiagramDescription(body, apiKey, maxCriticRounds, referenceAnalysis)
    const svg = await callSvgModel(body.provider, body.mainModelName, apiKey, description)
    return { content: svg, encoding: 'utf8' as const, mimeType: 'image/svg+xml', description }
  }

  if ((body.pipelineMode || 'planner_critic') === 'vanilla') {
    const prompt = diagramPrompt(body.methodContent, body.caption, referenceAnalysis)
    const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, prompt, body.aspectRatio || '16:9')
    return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description: prompt }
  }

  const description = await planDiagramDescription(body, apiKey, maxCriticRounds, referenceAnalysis)
  const imagePrompt = diagramPromptFromDescription(description)
  const base64 = await callImageModel(body.provider, body.imageModelName, apiKey, imagePrompt, body.aspectRatio || '16:9')
  return { content: base64, encoding: 'base64' as const, mimeType: 'image/png', description }
}

async function planDiagramDescription(body: CreateJobBody, apiKey: string, maxCriticRounds: number, referenceAnalysis = '') {
  if ((body.pipelineMode || 'planner_critic') === 'vanilla') {
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
  )

  let description = planner
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
  const visionInputs = await buildVisionImageInputs(references)
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

async function buildVisionImageInputs(referenceImages: ReferenceImageInput[]) {
  const bucket = cloud.storage.bucket(bucketName)
  const inputs = []

  for (const image of referenceImages) {
    const objectKey = image.analysisObjectKey || image.objectKey
    const mimeType = image.analysisMimeType || image.mimeType
    if (!objectKey) throw new Error(`Reference image ${image.filename || ''} is missing objectKey`)
    if (!allowedAnalysisMimeTypes.has(mimeType)) {
      throw new Error('SVG reference images require a rasterized PNG analysis upload')
    }
    const url = await bucket.getDownloadUrl(objectKey, 3600)
    inputs.push({
      filename: image.filename,
      mimeType,
      url,
    })
  }

  return inputs
}

async function callVisionModel(
  provider: Provider,
  model: string,
  apiKey: string,
  methodContent: string,
  caption: string,
  images: Array<{ filename: string; mimeType: string; url: string }>,
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

  const response = await fetch(`${baseUrl}/chat/completions`, {
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
  })
  const data = await parseModelResponse(response)
  return data.choices?.[0]?.message?.content || ''
}

async function callGeminiVision(
  model: string,
  apiKey: string,
  methodContent: string,
  caption: string,
  images: Array<{ filename: string; mimeType: string; url: string }>,
): Promise<string> {
  const parts: any[] = [{ text: referenceVisionUserPrompt(methodContent, caption) }]
  for (const image of images) {
    parts.push({
      inlineData: {
        mimeType: image.mimeType,
        data: await fetchImageAsBase64(image.url),
      },
    })
  }

  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: referenceVisionSystemPrompt() }] },
      contents: [{ role: 'user', parts }],
      generationConfig: { temperature: 0.2 },
    }),
  })
  const data = await parseModelResponse(response)
  return data.candidates?.[0]?.content?.parts?.map((part: any) => part.text || '').join('') || ''
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
  const actualModel = normalizeModelName('gemini', model)
  const response = await fetch(`https://generativelanguage.googleapis.com/v1/models/${actualModel}:generateContent?key=${apiKey}`, {
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
  let svg = extractSvg(raw)
    .replace(/<\?xml[\s\S]*?\?>/gi, '')
    .replace(/<!doctype[\s\S]*?>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .trim()

  if (!/^<svg[\s>]/i.test(svg)) {
    throw new Error('SVG model output did not contain a valid <svg> root')
  }

  const forbiddenElement = /<(script|foreignObject|iframe|object|embed|link|meta|base|audio|video|canvas|image)\b/i
  if (forbiddenElement.test(svg)) {
    throw new Error('SVG output contained unsupported unsafe elements')
  }

  const styleBlocks = [...svg.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)].map((match) => match[1] || '')
  const unsafeStylePattern = /(@import|javascript:|url\s*\(\s*['"]?\s*(?:https?:|data:|javascript:))/i
  if (styleBlocks.some((style) => unsafeStylePattern.test(style))) {
    throw new Error('SVG output contained unsupported unsafe style references')
  }

  const unsafePattern = /(on[a-z]+\s*=|javascript:|data:text\/html|@import|url\s*\(\s*['"]?\s*(?:https?:|data:|javascript:)|href\s*=\s*['"]?\s*(?:https?:|data:|javascript:)|xlink:href\s*=\s*['"]?\s*(?:https?:|data:|javascript:))/i
  if (unsafePattern.test(svg)) {
    throw new Error('SVG output contained unsupported unsafe references')
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

    if (mimeType === 'image/svg+xml' && !normalized.analysisObjectKey) {
      throw new Error('SVG reference images require a rasterized PNG analysis upload')
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
  if ((body.referenceImages || []).length && !body.referenceVisionModelName) throw new Error('referenceVisionModelName is required when referenceImages are provided')
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
  return refreshed.map((image) => ({
    filename: image.filename || '',
    objectKey: image.objectKey || '',
    url: image.url || '',
    storage: image.storage || 'bucket',
    mimeType: image.mimeType || '',
    size: Number(image.size || 0),
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
  if (Array.isArray(forwarded)) return forwarded[0] || ''
  return forwarded || ctx.headers?.['x-real-ip'] || ''
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

function clamp(value: number, min: number, max: number) {
  if (Number.isNaN(value)) return min
  return Math.max(min, Math.min(value, max))
}
