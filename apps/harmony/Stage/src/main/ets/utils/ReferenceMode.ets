import { ReferenceImageMode } from '../models/Types'

export interface ReferenceModeState {
  resolvedRequestMode: ReferenceImageMode
  referenceModeCanSubmit: boolean
  referenceModeNote: string
  shouldShowReferenceModeSelector: boolean
  canSelectMainModelDirect: boolean
  needsVisionModel: boolean
}

export function defaultReferenceImageMode(mainModelCanRead: boolean): ReferenceImageMode {
  return mainModelCanRead ? 'main_model' : 'vision_model'
}

export function normalizeReferenceImageMode(mode: string, fallback: ReferenceImageMode = 'vision_model'): ReferenceImageMode {
  if (mode === 'main_model' || mode === 'vision_model') return mode
  return fallback
}

export function buildReferenceModeState(
  hasReferenceImages: boolean,
  isAdvancedMode: boolean,
  requestedMode: string,
  mainModelCanRead: boolean,
): ReferenceModeState {
  const fallbackMode = defaultReferenceImageMode(mainModelCanRead)
  if (!hasReferenceImages) {
    return {
      resolvedRequestMode: fallbackMode,
      referenceModeCanSubmit: true,
      referenceModeNote: '',
      shouldShowReferenceModeSelector: false,
      canSelectMainModelDirect: mainModelCanRead,
      needsVisionModel: false,
    }
  }

  const resolvedRequestMode = isAdvancedMode ? normalizeReferenceImageMode(requestedMode, fallbackMode) : fallbackMode
  const directUnsupported = resolvedRequestMode === 'main_model' && !mainModelCanRead
  return {
    resolvedRequestMode,
    referenceModeCanSubmit: !directUnsupported,
    referenceModeNote: directUnsupported
      ? '当前主模型不支持直接看参考图，请改用独立识别模型或更换主模型。'
      : mainModelCanRead
        ? '当前主模型支持图像理解，将用主模型直读参考图。'
        : '当前主模型为文本模型，将使用独立识别模型读取参考图。',
    shouldShowReferenceModeSelector: isAdvancedMode,
    canSelectMainModelDirect: mainModelCanRead,
    needsVisionModel: resolvedRequestMode !== 'main_model',
  }
}

export function formatReferenceImageMode(mode: string): string {
  if (mode === 'main_model') return '主模型直读'
  if (mode === 'vision_model') return '独立识别模型'
  if (mode === 'auto') return '自动选择'
  return '未使用'
}
