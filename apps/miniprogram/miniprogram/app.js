"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const jobs_1 = require("./utils/jobs");
const session_1 = require("./utils/session");
App({
    globalData: {
        launchTime: Date.now(),
    },
    onLaunch() {
        wx.setStorageSync('paperbanana_last_launch', Date.now());
        // 启动即恢复登录态（cookie 在 storage 里），各页面通过 utils/session 订阅
        void (0, session_1.refreshSession)();
        // 清理上次会话落盘的结果图/阶段图缓存，避免 USER_DATA_PATH 越积越满
        (0, jobs_1.cleanupCachedImages)();
    },
});
