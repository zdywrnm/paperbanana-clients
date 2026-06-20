# PaperBanana — App Store 商店文案

> 本文件供填写 App Store Connect 的「App 信息」与「本地化」字段。
> 中文（zh-Hans，简体中文，主语言）+ 英文（en-US）两版并列。
> 字符上限按 App Store Connect 现行规则：App 名称 ≤30、副标题 ≤30、关键词 ≤100、描述 ≤4000。

---

## 1. App 名称 / App Name（≤30 字符）

| 语言 | 建议值 | 字符数 |
|------|--------|--------|
| 中文 zh-Hans | `PaperBanana 论文配图生成` | 17 |
| 英文 en-US | `PaperBanana: Paper Figures` | 26 |

备选（更强调品类）：
- 中文：`PaperBanana 学术配图AI` （15）
- 英文：`PaperBanana - AI Figure Maker` （29）

> 注：App Store 同一 App 全球只有一个「主名称」可影响搜索，建议主语言用中文名（含品牌 + 「论文配图」品类词），英文本地化用英文名。

---

## 2. 副标题 / Subtitle（≤30 字符）

| 语言 | 建议值 | 字符数 |
|------|--------|--------|
| 中文 | `多智能体生成出版级论文插图` | 13 |
| 英文 | `Multi-agent academic diagrams` | 30 |

备选：
- 中文：`AI 一键生成方法框架图/流程图` （16）
- 英文：`AI figures for papers & theses` （30）

---

## 3. 描述 / Description

### 中文（zh-Hans）

```
PaperBanana 把你的论文方法描述和图题，变成出版级的学术配图。

不再为了画一张方法框架图在绘图软件里耗一下午——输入方法内容、写好图注、选好图类，PaperBanana 的多智能体流水线就会替你完成「规划 → 渲染 → 评审 → 精修」的全过程，产出可直接放进论文的方法框架图、流程图、系统架构图与数据统计图。

【多智能体协作，像审稿一样打磨】
后端由多个 AI 角色分工协作：规划器先把方法拆成模块与连接关系，图像模型渲染初版，评审模型像审稿人一样检查排版、文字与逻辑并提出修改意见，再迭代重渲染，最后自动精修放大到 2K / 4K。整个流水线在 App 内可视化呈现，每一步「为什么这样画」都看得见。

【自带 API Key，模型自由选】
BYOK（Bring Your Own Key）模式：接入百炼（bailian）、OpenRouter、Gemini、OpenAI 等平台，自由搭配主模型、图像模型与视觉模型。你的 API Key 只保存在本机 Keychain，绝不上传到我们的服务器。

【为科研而生】
· 内置方法框架图、流程图、系统架构、数据统计等学术图类
· 支持上传参考图，贴合你的论文风格
· 普通 / 专业双模式，可调候选数量、评审轮数、长宽比、导出格式
· 导出 PNG 或可无损缩放的 SVG，方便后续排版精修
· 原生 iOS 26 液态玻璃设计，iPhone 与 iPad 通用

适合论文作者、研究生、科研人员，以及任何需要把复杂方法讲清楚的人。

PaperBanana —— 让做图不再是论文里最慢的那一步。

官网：https://www.paperbanana.asia/
```

### 英文（en-US）

```
PaperBanana turns your paper's method description and figure caption into publication-ready academic figures.

Stop spending an afternoon in drawing software just to make one method diagram. Describe your method, write the caption, pick a figure type — and PaperBanana's multi-agent pipeline runs the full "plan → render → critique → refine" process for you, producing method-framework diagrams, flowcharts, system architectures, and data charts you can drop straight into your paper.

MULTI-AGENT COLLABORATION, POLISHED LIKE PEER REVIEW
The backend coordinates several AI roles: a planner breaks your method into modules and connections, an image model renders the first draft, a critic model inspects layout, text, and logic like a reviewer and suggests fixes, then it re-renders and finally auto-enhances to 2K / 4K. The whole pipeline is visualized inside the app, so you can see why every step looks the way it does.

BRING YOUR OWN KEY, CHOOSE ANY MODEL
BYOK mode: connect Bailian, OpenRouter, Gemini, or OpenAI, and freely mix main, image, and vision models. Your API key is stored only in your device's Keychain and never uploaded to our servers.

BUILT FOR RESEARCH
· Built-in academic figure types: method framework, flowchart, system architecture, data charts
· Upload reference images to match your paper's style
· Simple and Pro modes — tune candidate count, critic rounds, aspect ratio, export format
· Export PNG, or lossless-scalable SVG for later typesetting
· Native iOS 26 Liquid Glass design, universal for iPhone and iPad

For paper authors, graduate students, researchers, and anyone who needs to explain a complex method clearly.

PaperBanana — so figures are no longer the slowest part of writing your paper.

Website: https://www.paperbanana.asia/
```

---

## 4. 关键词 / Keywords（≤100 字符，逗号分隔，无空格更省字符）

### 中文（zh-Hans）

```
论文配图,学术插图,方法框架图,流程图,科研绘图,论文图表,AI绘图,figure,diagram,科研,毕业论文,期刊配图
```
字符数：约 62（中文按字符计；逗号占位）。

### 英文（en-US）

```
academic figure,paper diagram,research,thesis,flowchart,architecture,scientific,AI figure,chart,methodology,plot
```
字符数：约 96。

> 提示：不要在关键词里重复 App 名称里已有的词（如「PaperBanana」），浪费字符。副标题里的词也已被搜索索引，关键词字段补充未覆盖的长尾词即可。

---

## 5. 分类建议 / Categories

| 项 | 建议 | 理由 |
|----|------|------|
| 主分类 Primary | **效率（Productivity）** | App 核心价值是「把做论文配图这件耗时的事自动化、提速」，本质是科研生产力工具；效率类竞争中等、与产品定位契合，且科研/论文写作工具普遍归此类。 |
| 次分类 Secondary | **图形与设计（Graphics & Design）** | 产物是图形（学术配图/图表），用户也会以「绘图/作图工具」心智搜索；次类覆盖图形设计相关搜索流量。 |

备选：若 App Store 审核更看重产物属性，可将主/次对调（主 = 图形与设计，次 = 效率）。推荐先用「效率」为主——科研工具受众在效率类更易触达。

---

## 6. 年龄分级问卷建议答案（目标分级：4+）

App Store Connect「年龄分级」问卷逐项建议（全部选「无 / None」即可得 4+）：

| 问卷项 | 建议答案 |
|--------|----------|
| 卡通或幻想暴力 | 无 |
| 现实暴力 | 无 |
| 性暗示或裸露内容 | 无 |
| 亵渎或低俗幽默 | 无 |
| 恐怖/惊悚主题 | 无 |
| 医疗/治疗信息 | 无 |
| 酒精、烟草或毒品的使用或相关内容 | 无 |
| 模拟赌博 / 真实赌博 | 无 |
| 用户生成内容 | **见说明** ↓ |
| 不限制的网页访问 | 无（App 不含内置浏览器/任意网页加载） |
| 色情或裸露 | 无 |

说明（用户生成内容相关）：
- PaperBanana 让用户输入文本（论文方法描述、图注）并由 AI 生成图像。生成图像主题局限于「学术配图」，且后端图像模型自带内容过滤（见 fixtures 中 `content filter triggered` 错误态）。
- App 内**无社交/UGC 公开分享、无评论区、无用户间内容浏览**，用户只能看到自己生成的内容。因此通常不触发「用户生成内容」导致的分级上调。
- 若 App Store Connect 仍要求就「AI 生成内容」声明：如实勾选「App 包含 AI 生成内容」相关项（Apple 2025 起的新问卷可能含此项），并说明生成内容仅限学术图示、有模型侧过滤、无公开分享。最终目标分级保持 **4+**。

> 不确定点：Apple 问卷条目会随版本调整；提交时以 App Store Connect 实际显示的条目为准，遇到上表未列出的新条目按「无暴力/无成人/无博彩」原则选「无」。

---

## 7. URL

| 字段 | 值 | 说明 |
|------|-----|------|
| 营销 URL（Marketing URL，可选） | `https://www.paperbanana.asia/` | 官网首页 |
| 支持 URL（Support URL，**必填**） | `https://www.paperbanana.asia/support` ⚠️占位 | **需确认该支持页真实存在**；若无独立支持页，可暂用官网首页 `https://www.paperbanana.asia/` 或一个含联系方式（邮箱/微信）的页面。App 内设置页还提供作者微信二维码作为联系渠道。 |
| 隐私政策 URL（Privacy Policy URL，**必填**） | 见同目录 `privacy-policy.html` 部署后的线上地址 ⚠️占位 | 由隐私政策文件部署到官网后填入，例如 `https://www.paperbanana.asia/privacy`。 |

---

## ⚠️ 占位符 / 用户必须确认或替换

- [ ] **支持 URL** — 确认 `paperbanana.asia/support` 是否存在；不存在则改为有效页面。
- [ ] **隐私政策 URL** — 部署 `privacy-policy.html` 后填入真实线上地址。
- [ ] **App 名称二选一** — 在「含品类词的中文名」与备选之间最终敲定（一旦上架不易改）。
- [ ] **分类主/次** — 确认用「效率 + 图形与设计」还是对调。
- [ ] 关键词字符数请在 App Store Connect 里以其计数器为准微调（中文按字符、含逗号）。
