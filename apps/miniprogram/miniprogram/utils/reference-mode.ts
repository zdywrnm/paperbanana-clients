export type ReferenceImageMode = 'main_model' | 'vision_model'
// 历史任务记录中可能仍存有 'auto'（旧版本提交的任务），展示层保留兼容。
export type ReferenceImageModeUsed = 'none' | 'main_model' | 'vision_model' | 'auto' | ''

export interface ReferenceModeInput {
  hasReferenceImages: boolean
  isAdvancedMode: boolean
  requestedMode: string
  mainModelCanRead: boolean
}

export interface ReferenceModeState {
  // 实际随 createJob 发送的模式（普通模式按主模型能力固定派生，不再发 'auto'）。
  resolvedRequestMode: ReferenceImageMode
  referenceModeCanSubmit: boolean
  referenceModeNote: string
  shouldShowReferenceModeSelector: boolean
  canSelectMainModelDirect: boolean
  needsVisionModel: boolean
}

// 与 apps/web/src/App.jsx 的派生逻辑同步：
// activeReferenceImageMode = advanced ? 用户所选 : (主模型能读图 ? main_model : vision_model)
export function defaultReferenceImageMode(mainModelCanRead: boolean): ReferenceImageMode {
  return mainModelCanRead ? 'main_model' : 'vision_model'
}

export function buildReferenceModeState(input: ReferenceModeInput): ReferenceModeState {
  const fallbackMode = defaultReferenceImageMode(input.mainModelCanRead)
  if (!input.hasReferenceImages) {
    return {
      resolvedRequestMode: fallbackMode,
      referenceModeCanSubmit: true,
      referenceModeNote: '',
      shouldShowReferenceModeSelector: false,
      canSelectMainModelDirect: input.mainModelCanRead,
      needsVisionModel: false,
    }
  }

  const resolvedRequestMode = input.isAdvancedMode
    ? normalizeReferenceImageMode(input.requestedMode, fallbackMode)
    : fallbackMode
  const directUnsupported = resolvedRequestMode === 'main_model' && !input.mainModelCanRead

  return {
    resolvedRequestMode,
    referenceModeCanSubmit: !directUnsupported,
    referenceModeNote: directUnsupported
      ? '当前主模型不支持直接看参考图，请改用独立识别模型或更换主模型。'
      : input.mainModelCanRead
        ? '当前主模型支持图像理解，将用主模型直读参考图。'
        : '当前主模型为文本模型，将使用独立识别模型读取参考图。',
    shouldShowReferenceModeSelector: input.isAdvancedMode,
    canSelectMainModelDirect: input.mainModelCanRead,
    needsVisionModel: resolvedRequestMode !== 'main_model',
  }
}

export function normalizeReferenceImageMode(mode: string, fallback: ReferenceImageMode = 'vision_model'): ReferenceImageMode {
  if (mode === 'main_model' || mode === 'vision_model') return mode
  return fallback
}

export function formatReferenceImageModeUsed(mode: ReferenceImageModeUsed): string {
  if (mode === 'main_model') return '主模型直读'
  if (mode === 'vision_model') return '独立识别'
  if (mode === 'auto') return '自动选择'
  return '未使用参考图'
}
