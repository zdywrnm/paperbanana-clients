# PaperBanana Clients

PaperBanana Clients 是 PaperBanana 的多端客户端 monorepo。这个仓库用于统一管理 Web、桌面端、移动端以及未来可复用的客户端共享代码。

当前 Web 端已经从 `PaperBanana-web/web-client` 迁移到 `apps/web`。生产站点 `paperbanana.asia` 暂时仍由原 `PaperBanana-web` 仓库的 GitHub Actions 发布。

## Apps

- `apps/web/`：PaperBanana Web 工作台，基于 React + Vite，已完成迁移。
- `apps/desktop/`：桌面端占位目录，后续用于承接 Electron / Tauri 客户端。
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
- 小程序代码暂不放在本仓库，后续单独规划。
