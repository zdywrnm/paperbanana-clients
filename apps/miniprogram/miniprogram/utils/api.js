"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestJson = requestJson;
exports.authRequest = authRequest;
exports.postJson = postJson;
exports.uploadReferenceFile = uploadReferenceFile;
exports.requestHeader = requestHeader;
exports.persistCookies = persistCookies;
exports.formatError = formatError;
const config_1 = require("./config");
function requestJson(body, options = {}) {
    return postJson(config_1.API_ENDPOINT, body, options);
}
function authRequest(path, method, data) {
    return new Promise((resolve, reject) => {
        const header = requestHeader(true);
        wx.request({
            url: `${config_1.AUTH_BASE}${path}`,
            method,
            timeout: 60000,
            header,
            data,
            success(res) {
                persistCookies(res);
                const responseData = res.data;
                if (res.statusCode < 200 || res.statusCode >= 300) {
                    const body = responseData || {};
                    reject(new Error(body.message || body.error || `HTTP ${res.statusCode}`));
                    return;
                }
                resolve(responseData);
            },
            fail(error) {
                reject(new Error(error.errMsg || '网络请求失败'));
            },
        });
    });
}
function postJson(url, body, options = {}) {
    return new Promise((resolve, reject) => {
        wx.request({
            url,
            method: 'POST',
            timeout: options.timeout || 60000,
            header: requestHeader(options.auth !== false),
            data: body,
            success(res) {
                persistCookies(res);
                const data = res.data || {};
                if (res.statusCode < 200 || res.statusCode >= 300 || (data.code && data.code !== 0)) {
                    reject(new Error(data.error || data.detail || `HTTP ${res.statusCode}`));
                    return;
                }
                resolve(data);
            },
            fail(error) {
                reject(new Error(error.errMsg || '网络请求失败'));
            },
        });
    });
}
function uploadReferenceFile(filePath, uploadUrl, mimeType) {
    return new Promise((resolve, reject) => {
        wx.getFileSystemManager().readFile({
            filePath,
            success(readResult) {
                wx.request({
                    url: uploadUrl,
                    method: 'PUT',
                    timeout: 60000,
                    header: {
                        'Content-Type': mimeType,
                    },
                    data: readResult.data,
                    success(res) {
                        if (res.statusCode >= 200 && res.statusCode < 300) {
                            resolve();
                            return;
                        }
                        reject(new Error(`参考图上传失败：HTTP ${res.statusCode}`));
                    },
                    fail(error) {
                        reject(new Error(error.errMsg || '参考图上传失败'));
                    },
                });
            },
            fail(error) {
                reject(new Error(error.errMsg || '读取参考图失败'));
            },
        });
    });
}
function requestHeader(includeAuth) {
    const header = {
        'content-type': 'application/json',
    };
    const cookie = wx.getStorageSync(config_1.AUTH_COOKIE_KEY);
    if (includeAuth && typeof cookie === 'string' && cookie) {
        header.Cookie = cookie;
    }
    return header;
}
function persistCookies(res) {
    const cookieLines = [];
    if (Array.isArray(res.cookies)) {
        cookieLines.push(...res.cookies);
    }
    const header = res.header || {};
    const setCookie = header['Set-Cookie'] || header['set-cookie'];
    if (Array.isArray(setCookie)) {
        cookieLines.push(...setCookie);
    }
    else if (typeof setCookie === 'string') {
        cookieLines.push(...splitSetCookieHeader(setCookie));
    }
    if (!cookieLines.length)
        return;
    const cookieMap = parseCookieHeader(wx.getStorageSync(config_1.AUTH_COOKIE_KEY) || '');
    cookieLines.forEach((line) => {
        const pair = String(line).split(';')[0];
        const index = pair.indexOf('=');
        if (index <= 0)
            return;
        const name = pair.slice(0, index).trim();
        const value = pair.slice(index + 1).trim();
        if (!value) {
            cookieMap.delete(name);
        }
        else {
            cookieMap.set(name, value);
        }
    });
    const nextCookie = Array.from(cookieMap.entries()).map(([name, value]) => `${name}=${value}`).join('; ');
    if (nextCookie) {
        wx.setStorageSync(config_1.AUTH_COOKIE_KEY, nextCookie);
    }
    else {
        wx.removeStorageSync(config_1.AUTH_COOKIE_KEY);
    }
}
function splitSetCookieHeader(header) {
    return header.split(/,(?=\s*[^;,=\s]+=[^;,]*)/g).map((item) => item.trim()).filter(Boolean);
}
function parseCookieHeader(header) {
    const cookieMap = new Map();
    header.split(';').forEach((part) => {
        const pair = part.trim();
        const index = pair.indexOf('=');
        if (index <= 0)
            return;
        cookieMap.set(pair.slice(0, index), pair.slice(index + 1));
    });
    return cookieMap;
}
function formatError(error) {
    const message = error instanceof Error ? error.message : String(error || '');
    if (message.includes('Invalid email or password'))
        return '邮箱或密码不正确。';
    if (message.includes('Invalid origin') || message.includes('Origin not allowed')) {
        return '登录请求被后端来源校验拦截。需要在网关的 FRONTEND_ORIGINS / Better Auth trustedOrigins 放行微信小程序来源后重新部署。';
    }
    if (message.includes('User already exists'))
        return '这个邮箱已经注册，请直接登录。';
    if (message.includes('Missing API key'))
        return '缺少所选模型接口的 API Key。';
    if (message.includes('Incorrect API key') || message.includes('apikey-error')) {
        return 'API Key 不正确。请确认当前选择的模型服务和填写的密钥匹配；如果选择阿里百炼，需要填写百炼控制台创建的 sk- 开头 API Key。';
    }
    if (message.includes('Please log in') || message.includes('请先登录') || message.includes('Unauthorized'))
        return '请先登录后再使用任务记录。';
    if (message.includes('Forbidden'))
        return '当前账号没有权限查看这个任务。';
    if (message.includes('url not in domain list'))
        return '请先在小程序后台配置 request 合法域名。';
    if (message.includes('timeout'))
        return '请求超时，请稍后重试。';
    if (message.includes('Invalid gateway token'))
        return '后端网关配置异常。';
    if (message.includes('password'))
        return '密码至少需要 8 位。';
    return message || '操作失败';
}
