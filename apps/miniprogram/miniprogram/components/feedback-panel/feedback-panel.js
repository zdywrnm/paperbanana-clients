"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const api_1 = require("../../utils/api");
const config_1 = require("../../utils/config");
const constants_1 = require("../../utils/constants");
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
        feedbackCategoryOptions: constants_1.FEEDBACK_CATEGORIES,
        feedbackCategoryIndex: 0,
        feedbackCategoryLabel: constants_1.FEEDBACK_CATEGORIES[0].label,
        feedbackMessage: '',
        feedbackContact: '',
        feedbackError: '',
        feedbackSubmitted: false,
        feedbackCanSubmit: false,
        isFeedbackSubmitting: false,
    },
    methods: {
        close() {
            this.setData({ feedbackError: '' });
            this.triggerEvent('close');
        },
        // 拦截点击冒泡，避免点对话框内容触发遮罩层的 close
        noop() { },
        onFeedbackCategoryChange(event) {
            const feedbackCategoryIndex = (0, constants_1.readPickerIndex)(event.detail.value, constants_1.FEEDBACK_CATEGORIES.length);
            const option = constants_1.FEEDBACK_CATEGORIES[feedbackCategoryIndex] || constants_1.FEEDBACK_CATEGORIES[0];
            this.setData({
                feedbackCategoryIndex,
                feedbackCategoryLabel: option.label,
            });
        },
        onFeedbackMessageInput(event) {
            this.setData({
                feedbackMessage: event.detail.value,
                feedbackSubmitted: false,
            });
            this.refreshFeedbackCanSubmit();
        },
        onFeedbackContactInput(event) {
            this.setData({ feedbackContact: event.detail.value });
        },
        refreshFeedbackCanSubmit() {
            // 门槛与后端/web 一致：非空即可提交（后端校验 1–2000 字，textarea maxlength 已限上限）
            this.setData({
                feedbackCanSubmit: Boolean(this.data.feedbackMessage.trim().length >= 1 && !this.data.isFeedbackSubmitting),
            });
        },
        async submitFeedback() {
            if (!this.data.feedbackCanSubmit || this.data.isFeedbackSubmitting)
                return;
            const category = constants_1.FEEDBACK_CATEGORIES[this.data.feedbackCategoryIndex] || constants_1.FEEDBACK_CATEGORIES[0];
            this.setData({
                isFeedbackSubmitting: true,
                feedbackError: '',
                feedbackSubmitted: false,
            });
            wx.showLoading({ title: '提交中' });
            try {
                await (0, api_1.requestJson)({
                    action: 'submitFeedback',
                    message: this.data.feedbackMessage.trim(),
                    category: category.value,
                    platform: 'miniprogram',
                    clientVersion: config_1.CLIENT_VERSION,
                    jobId: this.data.jobId || undefined,
                    contact: this.data.feedbackContact.trim() || undefined,
                });
                this.setData({
                    feedbackMessage: '',
                    feedbackContact: '',
                    feedbackSubmitted: true,
                });
                wx.hideLoading();
                wx.showToast({ title: '已收到反馈', icon: 'success' });
            }
            catch (error) {
                this.setData({ feedbackError: (0, api_1.formatError)(error) });
                wx.hideLoading();
            }
            finally {
                this.setData({ isFeedbackSubmitting: false });
                this.refreshFeedbackCanSubmit();
            }
        },
    },
});
