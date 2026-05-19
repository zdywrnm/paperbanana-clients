# PaperBanana Windows Desktop

PaperBanana Windows 端是 Electron 桌面壳，默认加载线上工作台：

```text
https://paperbanana.asia/
```

## 当前能力

- 单实例运行，重复打开会聚焦已有窗口。
- 记住上次窗口位置、尺寸和最大化状态。
- 外部链接使用系统默认浏览器打开。
- 禁止 WebView、Node 集成和任意权限请求。
- 网络异常时显示 PaperBanana 风格的重试页。
- 支持 NSIS 安装包和 portable 免安装版。

## 本地开发

从仓库根目录安装依赖：

```bash
pnpm install
```

启动桌面端：

```bash
pnpm --filter @paperbanana/desktop dev
```

默认加载生产站点。开发时可以复制 `.env.example`，或直接传入本地 Web 地址：

```bash
PAPERBANANA_DESKTOP_URL=http://localhost:5173 pnpm --filter @paperbanana/desktop dev
```

## 检查与构建

语法检查：

```bash
pnpm --filter @paperbanana/desktop check
```

构建 Windows 安装包：

```bash
pnpm --filter @paperbanana/desktop build:win
```

构建 Windows 免安装版：

```bash
pnpm --filter @paperbanana/desktop build:win:portable
```

产物输出到：

```text
apps/desktop/release/
```

## 发布

Windows 发布由 `.github/workflows/release-desktop-windows.yml` 执行。

手动发布时，在 GitHub Actions 里运行 `Release Windows Desktop`，输入与 `apps/desktop/package.json` 一致的版本号，例如：

```text
0.1.2
```

也可以推送标签触发：

```bash
git tag desktop-v0.1.2
git push origin desktop-v0.1.2
```

发布后会生成 GitHub Release，并上传：

- `PaperBanana-Setup-<version>.exe`
- `PaperBanana-Portable-<version>.exe`
