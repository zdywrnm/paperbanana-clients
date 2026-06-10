"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const media_1 = require("../../utils/media");
Component({
    options: {
        styleIsolation: 'apply-shared',
    },
    properties: {
        stages: {
            type: Array,
            value: [],
        },
        references: {
            type: Array,
            value: [],
        },
    },
    methods: {
        previewStageImage(event) {
            const url = String(event.currentTarget.dataset.url || '');
            const canPreview = event.currentTarget.dataset.canPreview;
            if (!url)
                return;
            if (canPreview === false || canPreview === 'false') {
                (0, media_1.copyImageUrl)(url);
                return;
            }
            wx.previewImage({ current: url, urls: [url] });
        },
    },
});
