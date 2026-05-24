# PaperBanana Android

PaperBanana Android 客户端，基于 Expo + React Native + TypeScript。

当前版本 `0.1.2`，Android 包名为 `asia.paperbanana.android`，功能对齐 Web 工作台的主要能力，并已按正式发布流程准备 32/64 位双 APK：

- 四个平台：阿里百炼、OpenRouter、Gemini、OpenAI
- 普通模式：平台 + API Key + 默认模型与流程
- 专业模式：后端地址、生成流程、检索设置、比例、候选图数量、评审轮数、模型名、模拟模式
- 登录 / 注册 / 退出
- 我的任务记录
- 任务提交、轮询、结果图预览
- Android 图标、状态栏、软键盘避让和移动端 UI 适配

## Development

从仓库根目录安装依赖：

```bash
pnpm install
```

启动开发服务：

```bash
pnpm --filter @paperbanana/android start
```

打开 Android：

```bash
pnpm --filter @paperbanana/android android
```

## APK Build

预览 APK，可用于内测或侧载验证：

```bash
pnpm --filter @paperbanana/android build:apk
```

本地构建 APK：

```bash
pnpm --filter @paperbanana/android build:apk:local
```

本地构建需要 Android Studio / Android SDK / Java 环境可用。用于发给测试用户或应用市场的 APK 必须是 release / preview build；debug APK 会尝试连接 Metro 开发服务器，直接安装后会提示 `Unable to load script`。

## Formal Release

正式应用市场发布建议使用双包上传：

- 32 位：`armeabi-v7a`
- 64 位：`arm64-v8a`

当前 `0.1.2` 正式分发包：

- [`PaperBanana-android-0.1.2-armeabi-v7a.apk`](https://github.com/zdywrnm/PaperBanana-clients/releases/download/android-preview-0.1.2/PaperBanana-android-0.1.2-armeabi-v7a.apk)
- [`PaperBanana-android-0.1.2-arm64-v8a.apk`](https://github.com/zdywrnm/PaperBanana-clients/releases/download/android-preview-0.1.2/PaperBanana-android-0.1.2-arm64-v8a.apk)

两个 APK 均使用同一包名 `asia.paperbanana.android`、同一版本名 `0.1.2`、同一版本号 `3`，并都内置 `assets/index.android.bundle`，不需要 Metro。

首次正式分发前需要妥善保存 Android 签名 keystore；同一个包名后续升级必须使用同一套签名。
