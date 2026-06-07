export type ReferenceImageMode = 'auto' | 'main_model' | 'vision_model'
export type ReferenceImageModeUsed = 'none' | 'main_model' | 'vision_model' | 'auto' | ''
export type CapabilityStatus = 'loading' | 'supported' | 'unsupported' | 'unknown'

interface CapabilityLike {
  status?: string
  reason?: string
}

interface ReferenceModeInput {
  hasReferenceImages: boolean
  isAdvancedMode: boolean
  requestedMode: string
  capability?: CapabilityLike | null
}

export function normalizeCapabilityStatus(capability?: CapabilityLike | null): CapabilityStatus {
  const status = capability && capability.status
  if (status === 'loading' || status === 'supported' || status === 'unsupported') return status
  return 'unknown'
}

export function buildReferenceModeState(input: ReferenceModeInput) {
  if (!input.hasReferenceImages) {
    return {
      referenceModeCanSubmit: true,
      referenceModeNote: '',
      resolvedRequestMode: 'auto' as ReferenceImageMode,
      shouldShowReferenceModeSelector: false,
    }
  }

  if (!input.isAdvancedMode) {
    return {
      referenceModeCanSubmit: true,
      referenceModeNote: '普通模式会自动选择参考图处理方式。',
      resolvedRequestMode: 'auto' as ReferenceImageMode,
      shouldShowReferenceModeSelector: false,
    }
  }

  const requestedMode = normalizeReferenceImageMode(input.requestedMode)
  const capabilityStatus = normalizeCapabilityStatus(input.capability)
  if (requestedMode === 'main_model' && capabilityStatus === 'unsupported') {
    return {
      referenceModeCanSubmit: false,
      referenceModeNote: '当前主模型不支持直接看参考图，请改用独立识别模型或更换主模型。',
      resolvedRequestMode: requestedMode,
      shouldShowReferenceModeSelector: true,
    }
  }

  return {
    referenceModeCanSubmit: true,
    referenceModeNote: describeReferenceCapability(input.capability),
    resolvedRequestMode: requestedMode,
    shouldShowReferenceModeSelector: true,
  }
}

export function normalizeReferenceImageMode(mode: string): ReferenceImageMode {
  if (mode === 'main_model' || mode === 'vision_model') return mode
  return 'auto'
}

export function formatReferenceImageModeUsed(mode: ReferenceImageModeUsed): string {
  if (mode === 'main_model') return '主模型直读'
  if (mode === 'vision_model') return '独立识别'
  if (mode === 'auto') return '自动选择'
  return '未使用参考图'
}

function describeReferenceCapability(capability?: CapabilityLike | null): string {
  const status = normalizeCapabilityStatus(capability)
  if (status === 'loading') return '正在检查当前主模型是否支持直接理解参考图。'
  if (status === 'supported') return '当前主模型支持直接理解参考图，可使用主模型直读。'
  if (status === 'unsupported') return '当前主模型不支持直接理解参考图，请使用独立识别模型或更换主模型。'
  return '当前主模型的参考图能力无法确认；可以尝试主模型直读，失败时改用独立识别模型。'
}
