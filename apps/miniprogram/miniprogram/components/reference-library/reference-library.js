"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const api_1 = require("../../utils/api");
const constants_1 = require("../../utils/constants");
const jobs_1 = require("../../utils/jobs");
Component({
    options: {
        styleIsolation: 'apply-shared',
    },
    properties: {
        // 'diagram' | 'plot'，随生成页所选信息图类别切换
        taskName: {
            type: String,
            value: 'diagram',
            observer() {
                this.loadLibrary();
            },
        },
        selectedIds: {
            type: Array,
            value: [],
            observer() {
                this.refreshCards();
            },
        },
    },
    data: {
        cards: [],
        isLoading: false,
        error: '',
        selectedCount: 0,
        limit: constants_1.MANUAL_REFERENCE_LIMIT,
    },
    lifetimes: {
        attached() {
            this.loadLibrary();
        },
    },
    methods: {
        // latest-wins：taskName 切换/手动刷新时无条件重新请求，仅最新一次请求的响应可落地
        // （不能用 isLoading 早退——会把加载途中的类别切换静默丢弃，面板停留在旧类别）
        async loadLibrary() {
            const seq = (this.loadSeq || 0) + 1;
            this.loadSeq = seq;
            this.setData({ isLoading: true, error: '' });
            try {
                const data = await (0, api_1.requestJson)({
                    action: 'referenceLibrary',
                    taskName: this.properties.taskName || 'diagram',
                    query: '',
                    limit: 24,
                });
                if (seq !== this.loadSeq)
                    return;
                this.references = (data.references || []).map(jobs_1.normalizeRetrievedReference);
                this.refreshCards();
                this.setData({ isLoading: false });
            }
            catch (error) {
                if (seq !== this.loadSeq)
                    return;
                this.setData({ error: (0, api_1.formatError)(error), isLoading: false });
            }
        },
        refreshCards() {
            const references = (this.references || []);
            const selectedIds = (this.properties.selectedIds || []);
            this.setData({
                cards: references.map((item) => ({
                    ...item,
                    selected: selectedIds.indexOf(item.id) >= 0,
                })),
                selectedCount: selectedIds.length,
            });
        },
        onToggle(event) {
            const id = String(event.currentTarget.dataset.id || '');
            if (!id)
                return;
            this.triggerEvent('toggle', { id });
        },
        onRefresh() {
            this.loadLibrary();
        },
    },
});
