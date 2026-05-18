# PaperBanana Laf Functions

这里归档 Laf 云开发中的云函数代码。当前线上函数仍在 Laf 控制台运行，本目录只是源码备份和维护入口。

## Functions

- `paperbanana-api.ts`: 生成任务、任务查询、管理员任务列表、模型调用、图片保存。

## Production

- Laf 应用名: `paperbanana-web`
- 云函数名: `paperbanana-api`
- 线上调用地址: `https://sdswgya641.sealoshzh.site/paperbanana-api`
- 数据集合: `paperbanana_jobs`
- 存储 bucket: `paperbanana`

## Deploy Manually

1. 打开 Laf 云开发控制台。
2. 进入 `paperbanana-web` 应用。
3. 打开云函数 `paperbanana-api`。
4. 将 `paperbanana-api.ts` 内容复制到 Laf 函数编辑器。
5. 配置 `.env.example` 中列出的环境变量。
6. 发布函数。

## Release Checklist

- `ADMIN_TOKEN` 已配置。
- `PAPERBANANA_BUCKET` 对应的 bucket 已存在。
- `paperbanana_jobs` 集合可写。
- 函数允许 HTTP 调用。
- `OPTIONS` 预检请求正常返回。
- 发布后先调用 `health` 动作确认 `{ runtime: "laf" }`。

## Notes

- 用户填写的模型 API Key 只在单次任务执行闭包中使用，不写入数据库。
- 不要把真实 `ADMIN_TOKEN` 或其他密钥提交到仓库。
- `@lafjs/cloud` 由 Laf 运行时提供，本目录不单独安装依赖。
