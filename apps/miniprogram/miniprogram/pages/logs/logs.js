"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
// logs.ts
// const util = require('../../utils/util.js')
const util_1 = require("../../utils/util");
Component({
    data: {
        logs: [],
    },
    lifetimes: {
        attached() {
            this.setData({
                logs: (wx.getStorageSync('logs') || []).map((log) => {
                    return {
                        date: (0, util_1.formatTime)(new Date(log)),
                        timeStamp: log
                    };
                }),
            });
        }
    },
});
