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

### [2026-06-08] 修复越权(IDOR)：Laf 校验网关共享 token — by Claude
变更：公开的 Laf 端点(`https://sdswgya641.sealoshzh.site/paperbanana-api`)此前完全信任调用方传入的 `userId`/`userEmail`,任何人直连即可用受害者 `userId` 读其任务历史(`method_content`/`caption`/结果图 URL),绕过网关会话鉴权。现在 Laf 对「依赖调用方身份」的非管理员动作校验网关注入的共享 token。
契约（影响其他端 / 共享）：
- **网关信任边界**：Laf 对 `createJob` / `refineImage` / `submitFeedback` / `userJobs` / `getJob` / `prepareReferenceUpload` 这些读写用户数据的动作,要求请求携带 `gatewayToken`(由 auth-gateway 的 `withGatewayToken` 注入到 **body**,值=env `PAPERBANANA_GATEWAY_TOKEN`),或携带有效 `adminToken`(=`ADMIN_TOKEN`);否则返回 `401`。
- **复用既有 env**:网关侧无需改代码(`withGatewayToken` 已就绪)。新增的是 **Laf env `PAPERBANANA_GATEWAY_TOKEN`**,必须与 auth-gateway 的同名 env 取**同一值**。
- **豁免**:`health` / `modelCapability` / `referenceLibrary` 为无害只读,不强制 token。
- **admin 动作不变**:`adminJobs` / `adminFeedback` / `importReferences` / `evaluateJob` / `pingPlotWorker` 仍用 `ADMIN_TOKEN` 直连 Laf,不受影响。
- **向后兼容/灰度**:Laf 未设 `PAPERBANANA_GATEWAY_TOKEN` 时**不强制**(fail-open,仅打 warn 日志),避免部署时序造成中断;两端都配置后才真正生效。
- **各端要求**:所有客户端必须把后端地址指向**网关域名**(`https://yifbnnzrwmxn.sealoshzh.site`,各端默认值已如此),**禁止把 base 改成 Laf 域名 `sdswgya641` 直连**——直连模式下身份动作会被拒。任何端若有绕过网关直连 Laf 的身份动作路径,需改走网关或在受信服务端注入该 token(切勿把 token 下发到客户端)。
部署：①生成强随机串 S;②auth-gateway(Sealos App Launchpad)env `PAPERBANANA_GATEWAY_TOKEN=S` 并重启;③Laf(Sealaf 控制台 paperbanana-api 函数)env `PAPERBANANA_GATEWAY_TOKEN=S` 并应用级重启;④push 改动 → CI `laf func push` 自动部署;⑤验证:网关→Laf 正常、直连伪造 userId 的 `userJobs` 返回 401。
各端待办：
- [x] laf-functions（校验 `gatewayToken`/`adminToken`,fail-open 兜底）
- [x] auth-gateway（无需改：`withGatewayToken` 已注入;仅需在 Sealos 配置 `PAPERBANANA_GATEWAY_TOKEN` env）
- [x] web（默认 `VITE_API_BASE` 指向网关,经网关转发,无需改）
- [ ] miniprogram（确认 `API_BASE` 指向网关域名,勿直连 Laf）
- [ ] android（确认 `API_BASE_DEFAULT` 指向网关域名,勿直连 Laf）
- [ ] windows（确认 `DefaultApiBase` 指向网关域名,勿直连 Laf）
- [ ] macos（默认 `sealosAPIBase` 指向网关;若用户把"网关地址"改成 Laf 域名,身份动作将被拒——属预期）

### [2026-06-08] 向 dwzhu-pku/PaperBanana 深度对齐（prompt 质量 + plot + 参考数据 + eval）— by Claude
变更：在 Codex 的 10 项基础上做实质对齐——移植 root 完整 agent prompts + 104 行 NeurIPS 风格指南；critic 改 root 的 JSON 契约 + 空图守卫 + 失败回滚；refine 改真·图生图；检索候选 80→200、infographicCategory 真正注入 prompt；导入 PaperBananaBench 真实参考图；接入 plot 任务（经独立 plot-worker 渲染）；新增管理员评估。
契约（影响其他端 / 共享）：
- `createJob` 现接受 `taskName:'plot'`：走 matplotlib 代码生成 → 调外部 plot-worker 渲染 → 图像 critic 迭代。**diagram 路径不变**。`packages/api` 的 `createJobRequest` 已白名单 `taskName`，前端传 `'plot'` 即可。
- 新增 **admin 动作**：`importReferences`（从 hf-mirror 导入 PaperBananaBench → `paperbanana_references` + 对象存储）、`evaluateJob`（LLM-judge 4 维评分：有 GT 做 referenced，否则 reference-free）。两者 `ADMIN_TOKEN` 鉴权、**直连 Laf**（不经网关）。
- `paperbanana_references` 现含 **295 条真实 diagram 参考图**（`source=paperbanana-bench`）；reference URL 一律从 `imageObjectKey` 重签，不存死 URL。
- 新增 **env（Laf）**：`PLOT_WORKER_URL`、`PLOT_WORKER_TOKEN`（plot 任务调用渲染服务）。
- critic 输出改为 root 的 JSON 契约 `{critic_suggestions, revised_description}`（后端内部解析，兼容旧纯文本，不影响客户端）。
- 新增独立服务 `apps/plot-worker`（Python/FastAPI matplotlib 沙箱，已硬化）+ CI `build-plot-worker.yml`，部署在 Sealos「应用管理」。
各端待办：
- [x] laf-functions（prompt/robustness/plot 管线/importReferences/evaluateJob）
- [x] packages/api（`taskName` 已白名单，无需改）
- [x] web（plot 提交放开：data_stat 类别 → `taskName:'plot'`）
- [x] auth-gateway（无需改：plot 走 createJob 既有转发；admin 动作直连 Laf）
- [ ] miniprogram/android/windows/macos（兼容 `taskName:'plot'`，后续补 plot UI）
- [x] plot-worker 已部署到 Sealos（Deployment+Service+NetworkPolicy，2Gi）+ Laf 已设 `PLOT_WORKER_URL`/`PLOT_WORKER_TOKEN`；`pingPlotWorker` 实测渲染通过

### [2026-06-08] PaperBanana 根项目 10 项功能对齐（diagram 主链路）— by Codex
变更：补齐 web 主链路的参考检索、手选参考、图像 Critic、Stylist 风格指南、pipeline stages、候选阶段记录、Refine Image、下载全部、管理员诊断摘要；`data_stat/plot` 明确标为二阶段能力，避免假入口。
契约：
- `createJob` 新增/启用 `taskName`、`retrievalSetting`(`none|auto|random|manual`)、`manualReferenceIds[]`；`manual` 必须带参考 id。
- 新增 action：`referenceLibrary`（列出 `paperbanana_references` + fallback 文本参考卡）、`refineImage`（源图 + 精修指令 → refine job）。
- `paperbanana_jobs/publicJob` 新增 `jobType`、`taskName`、`infographicCategory`、`retrievalSetting`、`manualReferenceIds`、`retrievedReferenceIds`、`retrievedReferences`、`stages`、`criticMode`、`imageSize`。
- `auth-gateway` 已放行 `referenceLibrary` / `refineImage`，精修会像 createJob 一样附登录用户身份；`ADMIN_TOKEN` 逻辑不变。
- 正式 PaperBananaBench 大图不进仓库；后续应把参考元数据导入 `paperbanana_references`，图片放对象存储。
各端待办：
- [x] laf-functions
- [x] auth-gateway
- [x] packages/api
- [x] web（manual 参考、timeline、zip、refine、plot 占位）
- [ ] miniprogram（兼容新增字段；后续补 UI）
- [ ] android（兼容新增字段；后续补 UI）
- [ ] windows（兼容新增字段；后续补 UI）
- [ ] macos（兼容新增字段；后续补 UI）
- [ ] plot render worker（二阶段：Python/matplotlib 执行与图像 Critic）

### [2026-06-07] 管理员改为账号制(邮箱白名单) — by Codex
变更：admin 鉴权从手填 `ADMIN_TOKEN` 改为“登录邮箱 ∈ `ADMIN_EMAILS`”；新增 `adminStatus`；前端去掉 token 框、按 `adminStatus` 显示站长入口。
契约：网关新增 env `ADMIN_EMAILS` + `adminStatus` 动作；admin 动作不再接收用户 `adminToken`（网关内部注入）；`ADMIN_TOKEN` 仅网关内部保留。
各端待办：
- [x] auth-gateway
- [x] web
- [x] packages/api
- [ ] miniprogram（如有 admin 入口）
- [ ] 其它端无 admin UI 暂不涉及

### [2026-06-07] 用户意见反馈 submitFeedback — by Codex
变更：新增意见反馈（匿名可提，登录后由网关自动附身份）。
契约：新 action `submitFeedback` + `adminFeedback`；新集合 `paperbanana_feedback`；网关放行这两个 action；任务无关；不读取/存储 `apiKeys`。
各端待办：
- [x] laf-functions
- [x] auth-gateway
- [x] web（含 admin 反馈页）
- [x] miniprogram

### [2026-06-07] Web 近期大版本同步基线 — by Codex
**变更**：Web 端已完成一轮大版本更新，其他端同步时应以这些 API/数据契约为基线，而不是只同步单个页面 UI。
**契约**：
- `createJob` 支持 `outputFormat: 'png' | 'svg'`；`png` 走图像模型，`svg` 走 SVG 文本生成链路并由后端做安全清洗。
- 任务记录需要展示并消费完整图片资产字段：`result_images` / `resultImages`、`reference_images` / `referenceImages`，每个资产按 `mimeType` / 文件名判断 PNG 或 SVG。
- 结果图和参考图下载都要支持 bucket 签名 URL、`data:` URL、`image/png`、`image/svg+xml`；失败任务也应该展示可用的 `reference_images`。
- 任务记录字段应同步展示：`output_format`、`main_model_name`、`image_gen_model_name`、`reference_vision_model_name`、`reference_image_mode`、`reference_image_mode_used`、`method_content`、`caption`、`error`。
- 账号任务记录通过 auth-gateway：登录用户走 `myJobs`，管理员任务走 `adminJobs`，账号列表走 `adminUsers`；客户端不要再靠手填 email 查询用户任务。
- 当前核心 action 基线：`health`、`createJob`、`getJob`、`userJobs`、`adminJobs`、`adminUsers`、`prepareReferenceUpload`、`modelCapability`。
- 模型列表已在 Web 端按最新表固化，其他端需要同步 provider/model 常量；阿里百炼主模型直读参考图仍不启用，继续走独立识别模型。
- 参考图上传、主模型直读、SVG 参考图服务端栅格化的细节见下方对应条目。
**用户反馈 / 回归重点**：
- 用户反馈过生成失败后信息不够明确；各端任务记录必须展示 `error`，必要时兜底展示 `logs_tail`。
- 用户反馈任务记录里的图片/文件不好下载；各端要区分 PNG 与 SVG：PNG 才走保存到相册/图片保存，SVG 走复制链接或文件下载。
- 用户反馈失败任务也需要保留输入上下文；各端不要只在 `status=succeeded` 时展示参考图和任务详情。
- 用户反馈模型输入不应自由填写；各端要使用固定 provider/model 列表，并跟 Web 常量保持一致。
**各端待办**：
- [x] laf-functions
- [x] auth-gateway
- [x] web
- [x] miniprogram
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

### [2026-06-07] SVG 参考图改服务端栅格化 — by Codex
**变更**：SVG 参考图不再要求客户端随附栅格化 PNG；后端会在需要喂给视觉模型/主模型直读时，把原始 SVG 服务端渲染为 PNG。
**契约**：
- `createJob.referenceImages[]` 中 SVG 参考图可以只传原始 `objectKey` / `mimeType=image/svg+xml`，不再强制 `analysisObjectKey`。
- Laf 后端遇到 SVG 且缺少 `analysisObjectKey` 时，会下载原始 SVG、sanitize、用 `@resvg/resvg-wasm` 栅格化为 PNG，并写回 bucket 为 `*-server-analysis.png`。
- 任务记录里的 `referenceImages[]` 会补上服务端生成的 `analysisObjectKey`、`analysisMimeType=image/png`、`analysisSize`；`publicJob` 同步返回 `analysisUrl`。
- 新增 env：`PAPERBANANA_SVG_REFERENCE_RASTER_WIDTH`，默认 `1024`，运行时限制在 `320-1536`。
- Laf 运行环境要求保留 Sealaf custom dependency：`@resvg/resvg-wasm`；wasm 路径按 `${CUSTOM_DEPENDENCY_BASE_PATH}/node_modules/@resvg/resvg-wasm/index_bg.wasm` 读取，不能使用 `require.resolve`。
- 各客户端只需要上传原始 SVG；不要再强制做本地 canvas/原生栅格化。Web 端已移除 `rasterizeSvgFile`。
- `auth-gateway` 无新增 action，无需改转发规则。
**用户反馈 / 回归重点**：
- 用户反馈非 Web 端无法使用 SVG 参考图；各端只上传原始 SVG 后，`main_model` 和 `vision_model` 两种参考图模式都必须能生成成功。
- 用户反馈大文件/大 payload 会导致小程序性能问题；各端不要把参考图或结果图 base64 写入页面状态或任务记录，只保留 URL/objectKey 元数据。
- 记录页应能看到原始 SVG 参考图；服务端生成的 PNG analysis 只用于模型理解和排查，不替代用户上传的原文件展示。
**各端待办**：
- [x] laf-functions
- [x] auth-gateway（无需改）
- [x] web
- [x] miniprogram
- [ ] android
- [ ] windows
- [ ] macos
