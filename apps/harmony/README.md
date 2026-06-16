# PaperBanana Harmony

PaperBanana Harmony 是原生 ArkTS / ArkUI 客户端，包名 `asia.paperbanana.harmony`，当前按 Phone 设备和 HarmonyOS `6.1.1(24)` 开发。

## 当前能力

- 邮箱密码登录、注册、退出，复用 Sealos auth-gateway 的 Better Auth 会话。
- BYOK 生成任务：阿里百炼、OpenRouter、Gemini、OpenAI。
- 普通 / 专业参数：图示类型、输出格式、清晰度、流程、检索、比例、候选图、评审轮数、固定模型选择器。
- 参考图上传：PNG/JPG/WebP/SVG，最多 3 张；上传参考图后检索自动关闭。
- 手动参考库：从 `referenceLibrary` 拉取 PaperBananaBench 参考案例，最多选 10 个。
- 任务提交、轮询、当前任务详情、生成阶段、结果图/参考图展示。
- 账号任务记录和意见反馈。

## 后端边界

默认网关：

```text
https://yifbnnzrwmxn.sealoshzh.site
```

客户端只调用：

```text
/paperbanana-api
/api/auth/*
```

不要把 `PAPERBANANA_GATEWAY_TOKEN`、`ADMIN_TOKEN` 或 Laf 环境变量写入客户端；身份动作必须经 auth-gateway 转发。

## 本地开发

用 DevEco Studio 打开：

```text
apps/harmony/
```

然后执行 Sync / Make Project / Run。当前模板生成的 `.idea`、`.hvigor`、`oh_modules`、`local.properties` 都由 `.gitignore` 排除。
