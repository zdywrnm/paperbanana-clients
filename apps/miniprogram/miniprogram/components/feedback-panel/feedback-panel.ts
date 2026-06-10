import { formatError, requestJson } from '../../utils/api'
import { CLIENT_VERSION } from '../../utils/config'
import { FEEDBACK_CATEGORIES, readPickerIndex } from '../../utils/constants'

Component({
  options: {
    styleIsolation: 'apply-shared',
  },

  properties: {
    show: {
      type: Boolean,
      value: false,
    },
    jobId: {
      type: String,
      value: '',
    },
  },

  data: {
    feedbackCategoryOptions: FEEDBACK_CATEGORIES,
    feedbackCategoryIndex: 0,
    feedbackCategoryLabel: FEEDBACK_CATEGORIES[0].label,
    feedbackMessage: '',
    feedbackContact: '',
    feedbackError: '',
    feedbackSubmitted: false,
    feedbackCanSubmit: false,
    isFeedbackSubmitting: false,
  },

  methods: {
    close() {
      this.setData({ feedbackError: '' })
      this.triggerEvent('close')
    },

    // 拦截点击冒泡，避免点对话框内容触发遮罩层的 close
    noop() {},

    onFeedbackCategoryChange(event: WechatMiniprogram.PickerChange) {
      const feedbackCategoryIndex = readPickerIndex(event.detail.value, FEEDBACK_CATEGORIES.length)
      const option = FEEDBACK_CATEGORIES[feedbackCategoryIndex] || FEEDBACK_CATEGORIES[0]
      this.setData({
        feedbackCategoryIndex,
        feedbackCategoryLabel: option.label,
      })
    },

    onFeedbackMessageInput(event: WechatMiniprogram.TextareaInput) {
      this.setData({
        feedbackMessage: event.detail.value,
        feedbackSubmitted: false,
      })
      this.refreshFeedbackCanSubmit()
    },

    onFeedbackContactInput(event: WechatMiniprogram.Input) {
      this.setData({ feedbackContact: event.detail.value })
    },

    refreshFeedbackCanSubmit() {
      this.setData({
        feedbackCanSubmit: Boolean(this.data.feedbackMessage.trim().length >= 4 && !this.data.isFeedbackSubmitting),
      })
    },

    async submitFeedback() {
      if (!this.data.feedbackCanSubmit || this.data.isFeedbackSubmitting) return
      const category = FEEDBACK_CATEGORIES[this.data.feedbackCategoryIndex] || FEEDBACK_CATEGORIES[0]
      this.setData({
        isFeedbackSubmitting: true,
        feedbackError: '',
        feedbackSubmitted: false,
      })
      wx.showLoading({ title: '提交中' })
      try {
        await requestJson<{ ok?: boolean; id?: string }>({
          action: 'submitFeedback',
          message: this.data.feedbackMessage.trim(),
          category: category.value,
          platform: 'miniprogram',
          clientVersion: CLIENT_VERSION,
          jobId: this.data.jobId || undefined,
          contact: this.data.feedbackContact.trim() || undefined,
        })
        this.setData({
          feedbackMessage: '',
          feedbackContact: '',
          feedbackSubmitted: true,
        })
        wx.hideLoading()
        wx.showToast({ title: '已收到反馈', icon: 'success' })
      } catch (error) {
        this.setData({ feedbackError: formatError(error) })
        wx.hideLoading()
      } finally {
        this.setData({ isFeedbackSubmitting: false })
        this.refreshFeedbackCanSubmit()
      }
    },
  },
})
