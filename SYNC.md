# 平台同步日志 (Platform Sync Log)

本仓库是多端 monorepo，由多个独立的 AI 会话 / 开发者分别开发各端
（`web` / `miniprogram` / `android` / `windows` / `macos` / `laf-functions` 后端 / `auth-gateway`）。
各会话互不可见——**本文件是唯一的跨端协调真相。**

## 协议（所有会话 / agent 必须遵守）
1. **开工前**：读下方「条目」里未完成的项，补齐你负责那一端欠的待办。
2. **当你改了"会影响其他端"的东西时**（见下「要记什么」），必须在「条目」最上方**新增一条**，
   写清 变更 / 契约 / 各端待办 checkbox；完成本端后把自己那一格打勾 `[x]`。
3. 只记**跨端契约级**变更；**纯单端 UI / 样式 / 文案 / 本地 bugfix 不用记**（git log 已经有）。

### 要记什么（= 会影响其他端，必须记）
- `createJob` 等请求/响应的字段增减或语义变化
- 新增 / 修改 action（如 `prepareReferenceUpload`、`modelCapability`）
- 共享 model 列表、provider、环境变量要求
- 任务记录（`paperbanana_jobs` / `publicJob`）字段变化
- `auth-gateway` 转发 / 鉴权规则变化

### 不用记
- 单端的 UI、样式、文案、纯本地 bugfix

---

## 条目（最新在上）

### [2026-06-07] 用户意见反馈 submitFeedback — by Codex
变更：新增意见反馈（匿名可提，登录后由网关自动附身份）。
契约：新 action `submitFeedback` + `adminFeedback`；新集合 `paperbanana_feedback`；网关放行这两个 action；任务无关；不读取/存储 `apiKeys`。
各端待办：
- [x] laf-functions
- [x] auth-gateway
- [x] web（含 admin 反馈页）
- [ ] miniprogram
- [ ] android
- [ ] windows
- [ ] macos

### [2026-06-07] 参考图上传 + 主模型直读 — by Codex
**变更**：新增参考图上传，以及「主模型直读 / 独立识别模型」两种参考图理解模式。
**契约**：
- `createJob` 新增 `referenceImages[]`、`referenceImageMode`(`auto|main_model|vision_model`)、`referenceVisionModelName`。
- 新增只读 action：`prepareReferenceUpload`（预签名直传对象存储）、`modelCapability`（查模型是否支持读图）。**`auth-gateway` 需放行转发这两个 action。**
- 任务记录新增 `referenceImages`、`referenceImageMode`、`referenceImageModeUsed`，并在 `publicJob` / `packages/api` 透出。
- 新增 env：`PAPERBANANA_MAX_REFERENCE_IMAGES`、`PAPERBANANA_MAX_REFERENCE_BYTES`、`PAPERBANANA_REFERENCE_UPLOAD_TTL_SECONDS`、`OPENROUTER_MODEL_CACHE_TTL_MS`。
- 注意：`packages/api/src/jobs.js` 的 `createJobRequest` 是**字段白名单**逐个拼包，新字段必须显式加进去才会发出去。
**各端待办**：
- [x] laf-functions
- [x] auth-gateway（已放行 prepareReferenceUpload / modelCapability）
- [x] web
- [x] miniprogram
- [ ] android
- [ ] windows
- [ ] macos

### [2026-06-07] 🔜 计划中（未实现）：SVG 参考图改服务端栅格化 — proposed
**目标**：让 SVG 参考图在**所有端**可用。现状是只有 web 能传——因为后端硬性要求 SVG 必须随附一份客户端栅格化的 PNG（`allowedAnalysisMimeTypes` 不含 svg），小程序/原生端产不出这份 PNG。
**方案**：后端用 `@resvg/resvg-wasm`（已装为 Sealaf custom dependency）把 SVG 渲染成 PNG；**取消"客户端必须随附栅格化 PNG"的硬要求**，各端只需上传原始 SVG。
- 已 spike 验证：resvg 在 Sealaf 运行时可用。wasm 路径 `${CUSTOM_DEPENDENCY_BASE_PATH}/node_modules/@resvg/resvg-wasm/index_bg.wasm`；`fs.readFileSync`→`initWasm(bytes)`（**全进程只调一次**）→`new Resvg(svg,{fitTo}).render().asPng()`。
- 实现注意：渲染前 sanitize 用户 SVG（禁 external href/script）；限制最大边（如 1024–1536px）。
**各端待办**：
- [ ] laf-functions（加服务端栅格化）
- [ ] web（可移除浏览器 `rasterizeSvgFile`，改为只传原始 SVG）
- [ ] miniprogram
- [ ] android
- [ ] windows
- [ ] macos
