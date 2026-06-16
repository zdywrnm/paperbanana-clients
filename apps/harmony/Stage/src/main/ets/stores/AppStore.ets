import { common } from '@kit.AbilityKit'
import {
  ASPECT_RATIO_OPTIONS,
  CANDIDATE_OPTIONS,
  categoryById,
  CRITIC_ROUND_OPTIONS,
  INFOGRAPHIC_CATEGORIES,
  mainModelCanReadImages,
  PIPELINE_OPTIONS,
  PLOT_CATEGORY_ID,
  providerById,
  PROVIDERS,
  QUICK_START_EXAMPLES,
  RETRIEVAL_OPTIONS,
  supportedResolutions,
} from '../constants/AppConstants'
import {
  ConfigurationMode,
  CreateJobInput,
  CurrentUser,
  HealthInfo,
  ImageSize,
  Job,
  OutputFormat,
  ProviderId,
  ReferenceImageMode,
  ReferenceImageUpload,
  RetrievedReference,
  RetrievalSetting,
} from '../models/Types'
import { formatErrorMessage, isFinishedStatus } from '../utils/Format'
import { buildCreateJobPayload } from '../utils/Payload'
import { buildReferenceModeState, defaultReferenceImageMode } from '../utils/ReferenceMode'
import { ApiClient } from '../services/ApiClient'
import { FileService } from '../services/FileService'
import { StorageService } from '../services/StorageService'

export class AppStore {
  api: ApiClient
  files: FileService

  activeTab: string = 'generate'
  error: string = ''
  notice: string = ''
  isBusy: boolean = false
  isSubmitting: boolean = false
  isPolling: boolean = false

  currentUser?: CurrentUser
  health?: HealthInfo
  jobs: Job[] = []
  currentJob?: Job
  referenceLibrary: RetrievedReference[] = []
  selectedReferenceIds: string[] = []
  referenceFiles: ReferenceImageUpload[] = []

  authMode: string = 'sign-in'
  authEmail: string = ''
  authPassword: string = ''
  authName: string = ''

  provider: ProviderId = 'bailian'
  configurationMode: ConfigurationMode = 'simple'
  apiKey: string = ''
  categoryId: string = 'method_framework'
  methodContent: string = QUICK_START_EXAMPLES[0].methodContent
  caption: string = QUICK_START_EXAMPLES[0].caption
  outputFormat: OutputFormat = 'png'
  imageSize: ImageSize = '1K'
  mainModelName: string = providerById('bailian').mainModel
  imageModelName: string = providerById('bailian').imageModel
  referenceVisionModelName: string = providerById('bailian').visionModel
  referenceImageMode: ReferenceImageMode = 'vision_model'
  pipelineMode: string = PIPELINE_OPTIONS[0].value
  retrievalSetting: RetrievalSetting = 'none'
  aspectRatio: string = ASPECT_RATIO_OPTIONS[0].value
  numCandidates: number = 1
  maxCriticRounds: number = 1

  feedbackMessage: string = ''
  feedbackContact: string = ''
  feedbackCategory: string = 'experience'

  constructor(context: common.UIAbilityContext) {
    const storage = new StorageService(context)
    this.api = new ApiClient(storage)
    this.files = new FileService(context, this.api)
  }

  async initialize(): Promise<void> {
    await this.api.restoreApiBase()
    await this.refreshHealth()
    await this.restoreSession()
    await this.loadReferenceLibrary()
  }

  async refreshHealth(): Promise<void> {
    this.health = await this.api.fetchHealth()
  }

  async restoreSession(): Promise<void> {
    this.currentUser = await this.api.getSession()
    if (this.currentUser) {
      await this.loadJobs()
    }
  }

  async signInOrUp(): Promise<void> {
    if (!this.authEmail.trim() || !this.authPassword.trim()) throw new Error('请填写邮箱和密码。')
    if (this.authMode === 'sign-up') {
      await this.api.signUp(this.authEmail.trim(), this.authPassword, this.authName.trim() || this.authEmail.trim())
    } else {
      await this.api.signIn(this.authEmail.trim(), this.authPassword)
    }
    await this.restoreSession()
  }

  async signOut(): Promise<void> {
    await this.api.signOut()
    this.currentUser = undefined
    this.jobs = []
  }

  async loadJobs(): Promise<void> {
    this.jobs = await this.api.myJobs()
  }

  async loadJob(jobId: string): Promise<void> {
    this.currentJob = await this.api.getJob(jobId)
  }

  async loadReferenceLibrary(): Promise<void> {
    const taskName = this.categoryId === PLOT_CATEGORY_ID ? 'plot' : 'diagram'
    this.referenceLibrary = await this.api.referenceLibrary(taskName)
  }

  async pickReferences(): Promise<void> {
    const picked = await this.files.pickReferenceFiles(this.referenceFiles.length)
    this.referenceFiles = [...this.referenceFiles, ...picked].slice(0, 3)
    if (this.referenceFiles.length) {
      this.retrievalSetting = 'none'
      this.selectedReferenceIds = []
    }
  }

  removeReferenceFile(id: string): void {
    this.referenceFiles = this.referenceFiles.filter((file: ReferenceImageUpload) => file.id !== id)
  }

  toggleManualReference(id: string): void {
    if (this.selectedReferenceIds.includes(id)) {
      this.selectedReferenceIds = this.selectedReferenceIds.filter((item: string) => item !== id)
      return
    }
    if (this.selectedReferenceIds.length >= 10) return
    this.selectedReferenceIds = [...this.selectedReferenceIds, id]
  }

  applyExample(index: number): void {
    const example = QUICK_START_EXAMPLES[index] || QUICK_START_EXAMPLES[0]
    this.categoryId = example.category
    this.methodContent = example.methodContent
    this.caption = example.caption
  }

  onProviderChange(provider: ProviderId): void {
    this.provider = provider
    const config = providerById(provider)
    this.mainModelName = config.mainModel
    this.imageModelName = config.imageModel
    this.referenceVisionModelName = config.visionModel
    this.referenceImageMode = defaultReferenceImageMode(mainModelCanReadImages(provider, this.mainModelName))
    this.clampResolution()
  }

  onCategoryChange(categoryId: string): void {
    this.categoryId = categoryId
    this.selectedReferenceIds = []
  }

  clampResolution(): void {
    const supported = supportedResolutions(this.provider, this.imageModelName)
    if (!supported.includes(this.imageSize)) {
      this.imageSize = supported[0]
    }
  }

  get referenceModeNote(): string {
    const state = buildReferenceModeState(
      this.referenceFiles.length > 0,
      this.configurationMode === 'advanced',
      this.referenceImageMode,
      mainModelCanReadImages(this.provider, this.mainModelName),
    )
    return this.referenceFiles.length > 0 ? state.referenceModeNote : ''
  }

  get canSubmit(): boolean {
    if (this.isSubmitting) return false
    if (!this.apiKey.trim()) return false
    if (!this.methodContent.trim() || !this.caption.trim()) return false
    if (this.retrievalSetting === 'manual' && this.configurationMode === 'advanced' && !this.referenceFiles.length && !this.selectedReferenceIds.length) return false
    return true
  }

  async submitJob(): Promise<void> {
    if (!this.canSubmit) throw new Error('请补齐 API Key、方法内容、图注和必要的参考设置。')
    this.isSubmitting = true
    this.currentJob = undefined
    try {
      const provider = providerById(this.provider)
      const category = categoryById(this.categoryId)
      const uploadedReferences = await this.files.uploadReferences(this.referenceFiles)
      const modeState = buildReferenceModeState(
        uploadedReferences.length > 0,
        this.configurationMode === 'advanced',
        this.referenceImageMode,
        mainModelCanReadImages(this.provider, this.mainModelName),
      )
      if (!modeState.referenceModeCanSubmit) throw new Error(modeState.referenceModeNote)

      const input: CreateJobInput = {
        configurationMode: this.configurationMode,
        provider: this.provider,
        apiKey: this.apiKey,
        categoryId: category.id,
        categoryLabel: category.label,
        methodContent: this.methodContent,
        caption: this.caption,
        outputFormat: this.outputFormat,
        imageSize: this.imageSize,
        mainModelName: this.configurationMode === 'advanced' ? this.mainModelName : provider.mainModel,
        imageModelName: this.configurationMode === 'advanced' ? this.imageModelName : provider.imageModel,
        referenceVisionModelName: this.configurationMode === 'advanced' ? this.referenceVisionModelName : provider.visionModel,
        referenceImageMode: modeState.resolvedRequestMode,
        uploadedReferenceImages: uploadedReferences,
        pipelineMode: this.pipelineMode,
        retrievalSetting: this.retrievalSetting,
        manualReferenceIds: this.selectedReferenceIds,
        aspectRatio: this.aspectRatio,
        numCandidates: this.numCandidates,
        maxCriticRounds: this.maxCriticRounds,
      }
      const created = await this.api.createJob(buildCreateJobPayload(input))
      await this.loadJob(created.id)
      await this.loadJobs().catch(() => undefined)
    } finally {
      this.isSubmitting = false
    }
  }

  async pollCurrentJob(): Promise<boolean> {
    if (!this.currentJob || isFinishedStatus(this.currentJob.status)) return false
    this.isPolling = true
    try {
      await this.loadJob(this.currentJob.id)
      if (this.currentUser) await this.loadJobs().catch(() => undefined)
      return Boolean(this.currentJob && !isFinishedStatus(this.currentJob.status))
    } catch (error) {
      this.error = formatErrorMessage(error)
      return false
    } finally {
      this.isPolling = false
    }
  }

  async submitFeedback(): Promise<void> {
    if (!this.feedbackMessage.trim()) throw new Error('请填写反馈内容。')
    await this.api.submitFeedback(
      this.feedbackMessage.trim(),
      this.feedbackCategory,
      this.currentJob?.id || '',
      this.feedbackContact.trim(),
    )
    this.feedbackMessage = ''
    this.feedbackContact = ''
    this.feedbackCategory = 'experience'
    this.notice = '反馈已提交。'
  }

  async safe(action: () => Promise<void>): Promise<void> {
    this.error = ''
    this.notice = ''
    this.isBusy = true
    try {
      await action()
    } catch (error) {
      this.error = formatErrorMessage(error)
    } finally {
      this.isBusy = false
    }
  }
}
