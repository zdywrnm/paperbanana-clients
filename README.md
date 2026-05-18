# PaperBanana Clients

PaperBanana Clients 是 PaperBanana 的多端 monorepo。这个仓库用于统一管理 Web、桌面端、移动端、后端网关以及未来可复用的共享代码。

当前 Web 端已经从 `PaperBanana-web/web-client` 迁移到 `apps/web`，生产站点 `paperbanana.asia` 由本仓库的 GitHub Actions 发布。

## Apps

- `apps/web/`：PaperBanana Web 工作台，基于 React + Vite，已完成迁移。
- `apps/desktop/`：Electron 桌面壳，加载线上 PaperBanana Web。
- `apps/miniprogram/`：微信小程序客户端，可直接用微信开发者工具打开。
- `apps/auth-gateway/`：Sealos 上运行的 Better Auth 登录网关和 Laf 代理。
- `apps/laf-functions/`：Laf 云函数源码归档。
- `apps/android/`：Android 端占位目录，后续用于承接移动端客户端。

## Packages

- `packages/api/`：共享 API client 封装。
- `packages/business/`：跨端复用的业务逻辑。
- `packages/design-tokens/`：颜色、字号、间距等设计变量。
- `packages/types/`：共享 TypeScript 类型。
- `packages/ui-core/`：共享 React UI 组件。

## Local Web Development

要求：

- Node.js `>=20`
- pnpm `10.28.2`

安装依赖：

```bash
pnpm install
```

配置 Web 环境变量：

```bash
cp apps/web/.env.example apps/web/.env.local
```

`.env.local` 只用于本地开发，不要提交。所有 `VITE_*` 变量都会被打包进前端 JS，不能放密钥、Token、数据库连接串或模型 API Key。

启动 Web：

```bash
pnpm --filter @paperbanana/web dev
```

默认访问：

```text
http://localhost:5173
```

构建 Web：

```bash
pnpm --filter @paperbanana/web build
```

## WeChat Mini Program

小程序工程位于：

```text
apps/miniprogram/
```

用微信开发者工具直接打开这个目录。代码检查和生成 `.js` 文件：

```bash
pnpm --filter @paperbanana/miniprogram check
pnpm --filter @paperbanana/miniprogram build
```

## Contributing

1. 从仓库根目录运行 pnpm 命令，避免在子目录混用 npm / yarn。
2. App 专属代码放在 `apps/*`，跨端共享逻辑优先放到 `packages/*`。
3. 不要提交 `.env.local`、`node_modules/`、`dist/`、`build/` 等本地生成文件。
4. 修改依赖后运行 `pnpm install`，并检查 `pnpm-lock.yaml` 是否符合预期。
5. 提交前至少验证相关 app 可以启动或构建，例如：

```bash
pnpm --filter @paperbanana/web build
```

## Notes

- Web 前端使用 BYOK 模式，用户自行填写模型 API Key。
- 登录和任务记录通过 Sealos 上的 auth-gateway / Laf 后端提供。
- 小程序需要在微信公众平台配置 `https://yifbnnzrwmxn.sealoshzh.site` 为 request/download/DNS/preconnect 合法域名。
