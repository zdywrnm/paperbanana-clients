# PaperBanana Android

PaperBanana Android 客户端，基于 Expo + React Native + TypeScript。

当前版本目标是先产出可侧载安装的 APK，不急于上架应用商店。功能对齐 Web 工作台的主要能力：

- 四个平台：阿里百炼、OpenRouter、Gemini、OpenAI
- 普通模式：平台 + API Key + 默认模型与流程
- 专业模式：后端地址、生成流程、检索设置、比例、候选图数量、评审轮数、模型名、模拟模式
- 登录 / 注册 / 退出
- 我的任务记录
- 站长观察面板
- 任务提交、轮询、结果图预览

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

预览 APK：

```bash
pnpm --filter @paperbanana/android build:apk
```

本地构建 APK：

```bash
pnpm --filter @paperbanana/android build:apk:local
```

本地构建需要 Android Studio / Android SDK / Java 环境可用。用于发给测试用户的 APK 必须是 release / preview build；debug APK 会尝试连接 Metro 开发服务器，直接安装后会提示 `Unable to load script`。

首次正式分发前需要妥善保存 Android 签名 keystore；同一个包名后续升级必须使用同一套签名。
