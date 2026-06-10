# PaperBanana 微信小程序

这是 PaperBanana 的微信小程序版，基于微信开发者工具原生 TypeScript 模板改造，并同步网站版的账号、任务记录和纸感 UI 风格。

## 当前功能

- 底部 tabBar 三页结构：生成 / 记录 / 教程，另有任务详情独立页
- 邮箱密码登录 / 注册，复用网站版 Better Auth 网关（登录态全局共享）
- 模型服务选择：阿里百炼、OpenRouter、Gemini、OpenAI（模型常量与 web 端同步）
- 用户填写自有 API Key（BYOK，不落盘）
- 输出清晰度 1K / 2K / 4K（按 provider/图像模型过滤；2K/4K 出图后自动精修放大）
- 检索设置：不使用 / 自动 / 随机 / 手动参考（手动参考可从 PaperBanana 参考库勾选最多 10 个案例）
- 上传参考图（PNG/JPG/WebP/SVG，最多 3 张）；上传后检索自动关闭并锁定提示
- 参考图处理方式按主模型能力固定派生（主模型直读 / 独立识别模型，无"自动选择"）
- 数据统计图类别走 `taskName: 'plot'`（独立渲染服务）
- 任务详情页展示多阶段「生成演化」时间线（规划 / 渲染 / 评审 / 精修放大）与检索参考
- 快速上手案例填充、健康检查、意见反馈
- 调用 PaperBanana 网关创建生成任务，登录后任务绑定到账号
- 轮询任务状态并展示候选图（tab 切换 / 页面隐藏时自动暂停轮询）
- 账号任务记录通过 `myJobs` 拉取，成功任务会补拉详情图
- 当前设备保存最近 10 条任务记录
- base64 结果图 / 阶段中间图会先缓存成本地临时文件，避免小程序 `setData` 数据过大
- 教程页：使用说明、参数解释、FAQ、联系作者二维码（长按识别）、关于与反馈入口

## 目录结构

```text
miniprogram/
├── app.json / app.ts / app.wxss   # tabBar、全局会话恢复、共享纸感样式
├── components/                    # auth-panel / feedback-panel / reference-library / stage-timeline
├── pages/
│   ├── index/                     # 生成页（tab1）
│   ├── records/                   # 任务记录页（tab2）
│   ├── guide/                     # 使用教程页（tab3）
│   └── job-detail/                # 任务详情页（navigateTo）
└── utils/                         # config / api / session / constants / jobs / payload / media 等纯逻辑层
tests/                             # node 断言单测（需先 tsc 编译出 .js）
```

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

保存结果图到相册使用 `wx.downloadFile`，对象存储签名 URL 的域名也需要加入 downloadFile 合法域名（开发期可勾选"不校验合法域名"）。

如果登录接口返回 `403 Invalid origin`，不是邮箱密码问题，而是 `auth-gateway` 的 Better Auth 来源校验拦截了微信环境。需要在网关部署环境变量 `FRONTEND_ORIGINS` 里追加微信小程序来源，并重新部署网关：

```text
https://www.paperbanana.asia,https://paperbanana.asia,http://localhost:5173,http://127.0.0.1:5173,https://servicewechat.com,https://developers.weixin.qq.com
```

如果后续 `api.paperbanana.asia` 在 Sealos 上完全绑定成功，可以把 `miniprogram/utils/config.ts` 里的 `API_BASE` 切到：

```text
https://api.paperbanana.asia
```

并把同名域名配置到小程序后台。

## 本地检查

```bash
npm run check   # tsc --noEmit
npm run build   # tsc 编译出 .js（tests 依赖编译产物）
node tests/reference-mode.test.cjs
node tests/job-assets.test.cjs
node tests/constants.test.cjs
node tests/payload.test.cjs
```

如果开发者工具报：

```text
["pages"][0] could not find the corresponding file: "pages/index/index.js"
```

说明工具没有把 `.ts` 编译成 `.js`。当前项目已在 `project.config.json` 和 `project.private.config.json` 启用 TypeScript 插件；如果仍然看到旧错误，先点开发者工具的“普通编译”，再使用“清缓存 -> 清除编译缓存”后重新编译。

微信开发者工具 CLI preview 需要先开启：

```text
微信开发者工具 -> 设置 -> 安全设置 -> 服务端口
```

## 参考文档

- https://developers.weixin.qq.com/miniprogram/dev/framework/
- https://developers.weixin.qq.com/miniprogram/dev/framework/ability/network.html
- https://developers.weixin.qq.com/miniprogram/dev/api/network/request/wx.request.html
- https://developers.weixin.qq.com/miniprogram/dev/reference/configuration/app.html
