const assert = require('node:assert/strict')

const {
  buildReferenceModeState,
  defaultReferenceImageMode,
  formatReferenceImageModeUsed,
  normalizeReferenceImageMode,
} = require('../miniprogram/utils/reference-mode.js')

// 缺省模式按主模型能力固定派生（不再有 auto）
assert.equal(defaultReferenceImageMode(true), 'main_model')
assert.equal(defaultReferenceImageMode(false), 'vision_model')

assert.equal(normalizeReferenceImageMode('main_model'), 'main_model')
assert.equal(normalizeReferenceImageMode('vision_model'), 'vision_model')
assert.equal(normalizeReferenceImageMode('auto'), 'vision_model')
assert.equal(normalizeReferenceImageMode('auto', 'main_model'), 'main_model')

// 专业模式选了主模型直读但主模型不能读图 → 阻止提交
const blocked = buildReferenceModeState({
  hasReferenceImages: true,
  isAdvancedMode: true,
  requestedMode: 'main_model',
  mainModelCanRead: false,
})
assert.equal(blocked.referenceModeCanSubmit, false)
assert.equal(blocked.resolvedRequestMode, 'main_model')
assert.equal(blocked.canSelectMainModelDirect, false)
assert.equal(blocked.referenceModeNote, '当前主模型不支持直接看参考图，请改用独立识别模型或更换主模型。')

// 普通模式按能力派生，不显示选择器，不发 auto
const simpleCanRead = buildReferenceModeState({
  hasReferenceImages: true,
  isAdvancedMode: false,
  requestedMode: 'vision_model',
  mainModelCanRead: true,
})
assert.equal(simpleCanRead.resolvedRequestMode, 'main_model')
assert.equal(simpleCanRead.referenceModeCanSubmit, true)
assert.equal(simpleCanRead.shouldShowReferenceModeSelector, false)
assert.equal(simpleCanRead.needsVisionModel, false)

const simpleTextModel = buildReferenceModeState({
  hasReferenceImages: true,
  isAdvancedMode: false,
  requestedMode: 'main_model',
  mainModelCanRead: false,
})
assert.equal(simpleTextModel.resolvedRequestMode, 'vision_model')
assert.equal(simpleTextModel.needsVisionModel, true)

// 没有参考图：一切放行，不需要识别模型
const noRefs = buildReferenceModeState({
  hasReferenceImages: false,
  isAdvancedMode: true,
  requestedMode: 'main_model',
  mainModelCanRead: false,
})
assert.equal(noRefs.referenceModeCanSubmit, true)
assert.equal(noRefs.needsVisionModel, false)
assert.equal(noRefs.shouldShowReferenceModeSelector, false)

// 展示层对旧记录的 auto 保留兼容
assert.equal(formatReferenceImageModeUsed('main_model'), '主模型直读')
assert.equal(formatReferenceImageModeUsed('vision_model'), '独立识别')
assert.equal(formatReferenceImageModeUsed('auto'), '自动选择')
assert.equal(formatReferenceImageModeUsed('none'), '未使用参考图')
assert.equal(formatReferenceImageModeUsed(''), '未使用参考图')

console.log('reference-mode.test.cjs passed')
