"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("../../utils/config");
const LINKS = {
    site: { label: '网站端', url: 'https://www.paperbanana.asia/' },
    github: { label: 'GitHub 仓库', url: 'https://github.com/zdywrnm/paperbanana-clients' },
    paper: { label: 'PaperBanana 论文', url: 'https://huggingface.co/papers/2601.23265' },
};
Component({
    data: {
        qrSrc: '/images/contact-qr.jpg',
        clientVersion: config_1.CLIENT_VERSION,
        showFeedbackPanel: false,
        scrollAnchor: '',
    },
    methods: {
        goGenerate() {
            wx.switchTab({ url: '/pages/index/index' });
        },
        scrollToContact() {
            // 页面滚动容器是 scroll-view，用 scroll-into-view 定位联系作者区块
            this.setData({ scrollAnchor: '' });
            wx.nextTick(() => {
                this.setData({ scrollAnchor: 'contact-section' });
            });
        },
        copyLink(event) {
            const key = String(event.currentTarget.dataset.key || '');
            const link = LINKS[key];
            if (!link)
                return;
            wx.setClipboardData({
                data: link.url,
                success() {
                    wx.showToast({ title: `${link.label}链接已复制`, icon: 'none' });
                },
            });
        },
        openFeedbackPanel() {
            this.setData({ showFeedbackPanel: true });
        },
        closeFeedbackPanel() {
            this.setData({ showFeedbackPanel: false });
        },
    },
});
