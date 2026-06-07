const assert = require('node:assert/strict')

const {
  buildReferenceModeState,
  formatReferenceImageModeUsed,
  normalizeCapabilityStatus,
} = require('../miniprogram/pages/index/reference-mode.js')

assert.equal(normalizeCapabilityStatus({ status: 'supported' }), 'supported')
assert.equal(normalizeCapabilityStatus({ status: 'unsupported' }), 'unsupported')
assert.equal(normalizeCapabilityStatus({ status: 'loading' }), 'loading')
assert.equal(normalizeCapabilityStatus({}), 'unknown')

assert.deepEqual(
  buildReferenceModeState({
    hasReferenceImages: true,
    isAdvancedMode: true,
    requestedMode: 'main_model',
    capability: { status: 'unsupported', reason: 'not multimodal' },
  }),
  {
    referenceModeCanSubmit: false,
    referenceModeNote: '当前主模型不支持直接看参考图，请改用独立识别模型或更换主模型。',
    resolvedRequestMode: 'main_model',
    shouldShowReferenceModeSelector: true,
  },
)

assert.deepEqual(
  buildReferenceModeState({
    hasReferenceImages: true,
    isAdvancedMode: false,
    requestedMode: 'main_model',
    capability: { status: 'supported' },
  }),
  {
    referenceModeCanSubmit: true,
    referenceModeNote: '普通模式会自动选择参考图处理方式。',
    resolvedRequestMode: 'auto',
    shouldShowReferenceModeSelector: false,
  },
)

assert.equal(formatReferenceImageModeUsed('main_model'), '主模型直读')
assert.equal(formatReferenceImageModeUsed('vision_model'), '独立识别')
assert.equal(formatReferenceImageModeUsed('none'), '未使用参考图')
assert.equal(formatReferenceImageModeUsed(''), '未使用参考图')
