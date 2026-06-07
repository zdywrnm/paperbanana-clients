# PaperBanana 微信小程序

这是 PaperBanana 的微信小程序版，基于微信开发者工具原生 TypeScript 模板改造，并同步网站版的账号、任务记录和纸感 UI 风格。

## 当前功能

- PaperBanana 品牌首页和 logo
- 邮箱密码登录 / 注册，复用网站版 Better Auth 网关
- 生成候选图 / 任务记录双 Tab
- 快速上手案例填充
- 模型服务选择：阿里百炼、OpenRouter、Gemini、OpenAI
- 模型下拉选项同步网站版固定模型表
- 用户填写自有 API Key
- 生成格式选择：PNG 图片 / SVG 矢量图
- 输入论文方法内容和目标图注
- 参考图上传：PNG、JPG、WebP，最多 3 张，单张不超过 5MB
- 专业模式可选择参考图处理方式：自动选择 / 主模型直读 / 独立识别模型
- 通过 `modelCapability` 判断主模型是否支持直接理解参考图
- 调用现有 PaperBanana 网关创建生成任务，登录后任务会绑定到账号
- 轮询任务状态并展示候选图
- 账号任务记录通过 `myJobs` 拉取，结果图和参考图都会按需补拉详情
- 任务记录展示导出格式、参考图处理方式、参考识别模型、参考图和结果图
- PNG/JPG/WebP 结果支持保存到相册；SVG 结果支持复制文件链接
- 当前设备保存最近 10 条任务记录
- base64 结果图会先缓存成本地临时文件，避免小程序 `setData` 数据过大

注意：网站版支持 SVG 参考图上传，并会在浏览器端栅格化成 PNG 给模型理解。小程序端暂时不接 SVG 参考图，避免缺少栅格化分析图导致后端拒绝任务。

## 后端接口

当前小程序请求：

```text
https://yifbnnzrwmxn.sealoshzh.site/paperbanana-api
https://yifbnnzrwmxn.sealoshzh.site/api/auth/*
```

正式预览、真机调试和发布前，需要到：

```text
小程序后台 -> 开发 -> 开发设置 -> 服务器域名
```

添加 request 合法域名：

```text
https://yifbnnzrwmxn.sealoshzh.site
```

如果登录接口返回 `403 Invalid origin`，不是邮箱密码问题，而是 `auth-gateway` 的 Better Auth 来源校验拦截了微信环境。需要在网关部署环境变量 `FRONTEND_ORIGINS` 里追加微信小程序来源，并重新部署网关：

```text
https://www.paperbanana.asia,https://paperbanana.asia,http://localhost:5173,http://127.0.0.1:5173,https://servicewechat.com,https://developers.weixin.qq.com
```

如果后续 `api.paperbanana.asia` 在 Sealos 上完全绑定成功，可以把 `miniprogram/pages/index/index.ts` 里的 `API_BASE` 切到：

```text
https://api.paperbanana.asia
```

并把同名域名配置到小程序后台。

## 本地检查

项目代码已通过 TypeScript 检查：

```bash
tsc --noEmit
```

如果开发者工具报：

```text
["pages"][0] could not find the corresponding file: "pages/index/index.js"
```

说明工具没有把 `.ts` 编译成 `.js`。当前项目已在 `project.config.json` 启用 TypeScript 插件；如果仍然看到旧错误，先从仓库根目录运行 `pnpm --filter @paperbanana/miniprogram build`，再点开发者工具的“普通编译”，必要时使用“清缓存 -> 清除编译缓存”后重新编译。

微信开发者工具 CLI preview 需要先开启：

```text
微信开发者工具 -> 设置 -> 安全设置 -> 服务端口
```

## 参考文档

- https://developers.weixin.qq.com/miniprogram/dev/framework/
- https://developers.weixin.qq.com/miniprogram/dev/framework/ability/network.html
- https://developers.weixin.qq.com/miniprogram/dev/api/network/request/wx.request.html
- https://developers.weixin.qq.com/miniprogram/dev/reference/configuration/app.html
