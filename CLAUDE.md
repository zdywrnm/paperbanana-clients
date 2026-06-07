# CLAUDE.md

本仓库的协作规范见 **[AGENTS.md](./AGENTS.md)**，请遵守同一套规则。

## ⚠️ 跨端协调（最重要）
这是多端 monorepo，各端常由不同的、互不可见的会话开发。
**开工前先读 [SYNC.md](./SYNC.md)：**
- 补齐你负责那一端在 SYNC.md 里未打勾的待办；
- 改了后端 / 共享契约（API 字段、action、model 列表、env、任务记录字段、网关规则）时，**必须**在 SYNC.md 顶部新增一条并标注各端待办，本端做完就打勾。
- 纯单端 UI / 样式 / 文案 / 本地 bugfix 不用记。

架构与部署见 [README.md](./README.md) 与 [AGENTS.md](./AGENTS.md)。
