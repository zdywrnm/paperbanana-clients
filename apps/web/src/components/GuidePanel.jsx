import {
  BookOpen,
  Sparkles,
  Workflow,
  SlidersHorizontal,
  Cpu,
  Image as ImageIcon,
  Search,
  HelpCircle,
  QrCode,
  ArrowRight,
} from 'lucide-react';

function Term({ name, children }) {
  return (
    <div className="guide-term">
      <strong>{name}</strong>
      <p>{children}</p>
    </div>
  );
}

export default function GuidePanel({ onStart, onContact }) {
  return (
    <section className="guide-panel">
      <div className="guide-head">
        <BookOpen size={22} />
        <div>
          <h2>使用教程</h2>
          <p>PaperBanana 是一个「多智能体」学术配图生成工具：把你论文里的方法描述 + 想要的图注交给它，多个 AI 角色协作产出框架图 / 流程图 / 统计图。你自带模型 API Key（BYOK），密钥只用于本次调用、不会存到本站。</p>
        </div>
      </div>

      <div className="guide-cta">
        <button type="button" className="guide-cta-primary" onClick={onStart}>
          <Sparkles size={16} /> 开始生成 <ArrowRight size={15} />
        </button>
        <button type="button" className="guide-cta-ghost" onClick={onContact}>
          <QrCode size={16} /> 联系作者
        </button>
      </div>

      <div className="guide-section">
        <h3><Sparkles size={17} /> 三步上手</h3>
        <ol className="guide-steps">
          <li><strong>选接口、填 Key。</strong>顶部「模型接口」选 OpenRouter / Gemini / OpenAI / 阿里百炼之一，填对应的 API 密钥（只填当前选中的那个即可）。</li>
          <li><strong>填内容。</strong>选「信息图类别」，粘贴论文的<em>方法部分</em>和<em>目标图注</em>；如果有风格参考，可上传参考图（最多 3 张）。</li>
          <li><strong>点「生成候选图」。</strong>几十秒后右侧出图，可单张下载或「下载全部」（含中间过程）。</li>
        </ol>
      </div>

      <div className="guide-section">
        <h3><Workflow size={17} /> 它是怎么生成的（多智能体流程）</h3>
        <p>专业模式下，一张图大致经历这些阶段（右侧「生成演化」会实时显示）：</p>
        <ol className="guide-flow">
          <li><strong>规划</strong>：主模型把你的方法+图注拆解成一份「目标图的详细描述」（有哪些模块、怎么连、什么布局）。</li>
          <li><strong>初次渲染</strong>：图像模型按规划画出第一版。</li>
          <li><strong>图像评审</strong>：评审模型「看」这版图，指出排版/文字/逻辑问题。</li>
          <li><strong>重渲染</strong>：按评审意见改进，重复「评审→重渲染」直到用完你设的轮数。</li>
          <li><strong>精修放大</strong>：若输出清晰度选了 2K/4K，最后自动放大到该分辨率。</li>
        </ol>
      </div>

      <div className="guide-section">
        <h3><Cpu size={17} /> 模型相关</h3>
        <Term name="模型接口（Provider）">选哪家的模型服务。每家模型名、能力、是否能读图都不同；切换接口会同步刷新下面的可选模型与清晰度。密钥只填当前选中的接口。</Term>
        <Term name="主模型">负责「动脑」的文本模型：写规划、做文本评审、自动检索时的相关性排序都靠它。建议选推理强的模型。</Term>
        <Term name="图像生成模型">真正「画图」的模型。它决定出图风格与上限分辨率（如部分模型最高只到 2K）。</Term>
        <Term name="参考图识别模型">当你上传参考图且用「独立识别模型」方式时，由这个具备图像理解能力的模型先把参考图读成文字描述，再交给生成。只有支持图像理解的模型才能选。</Term>
      </div>

      <div className="guide-section">
        <h3><SlidersHorizontal size={17} /> 生成参数</h3>
        <Term name="使用模式">「普通模式」用平台预置配置，最省心；「专业模式」放开全部模型与流程参数，可精细控制。</Term>
        <Term name="生成流程">
          决定智能体协作的复杂度：<br />
          · <strong>规划器 + 评审器</strong>：规划→渲染→评审→重渲染，质量与速度平衡（推荐）。<br />
          · <strong>完整流程</strong>：加入更多风格/细化环节，最讲究但更慢更耗 token。<br />
          · <strong>基础生成</strong>：跳过评审，规划完直接出图，最快。
        </Term>
        <Term name="候选图数量">一次生成几张互相独立的备选图（1–3）。多出几张方便挑，但耗时与花费成倍增加。</Term>
        <Term name="评审轮数">「评审→重渲染」的迭代次数（0–3）。0 = 不评审直接出；轮数越多越精细，但越慢。</Term>
        <Term name="画面比例">输出图的长宽比（16:9 / 21:9 / 3:2 / 1:1），按你要放进论文/幻灯的版面选。</Term>
        <Term name="导出格式">PNG（位图，通用）或 SVG（矢量，可无损缩放、适合排版精修）。</Term>
        <Term name="输出清晰度">
          唯一的分辨率开关：<strong>1K</strong> = 只做基础渲染（最快）；<strong>2K / 4K</strong> = 出图后自动再「精修放大」到该清晰度。选项会按所选图像模型自动过滤（模型到不了的档位不出现）。
        </Term>
      </div>

      <div className="guide-section">
        <h3><Search size={17} /> 检索设置 & 参考图</h3>
        <p className="guide-note">两者都用来给生成「视觉参考」，但二选一：<strong>一旦你上传了参考图，检索会自动关闭</strong>，以你的图为唯一风格来源（避免多张参考互相打架）。</p>
        <Term name="检索设置 · 不使用检索">不带任何范例，完全按你的文字生成。</Term>
        <Term name="检索设置 · 自动检索">从内置的 PaperBanana 论文配图库里，让主模型挑出最相关的若干张范例（最多 10 张），作为风格与排版灵感。</Term>
        <Term name="检索设置 · 随机参考">从库里随机取若干张，做风格灵感（不讲相关性）。</Term>
        <Term name="检索设置 · 手动参考">你自己从案例库里翻看并勾选最多 10 张范例。</Term>
        <Term name="上传参考图 · 处理方式">
          · <strong>主模型直读</strong>：参考图直接喂给能读图的主模型；<br />
          · <strong>独立识别模型</strong>：先用「参考图识别模型」把图读成文字再用（当主模型不能读图时自动走这条）。
        </Term>
        <p className="guide-note">无论检索还是上传，参考图只用来<strong>学风格</strong>（配色、线条、图标、字体）；图的<strong>版式与内容</strong>始终由你的方法+图注决定，不会去照搬参考的布局。</p>
      </div>

      <div className="guide-section">
        <h3><ImageIcon size={17} /> 看懂右侧结果区</h3>
        <Term name="参考回显">把你上传的参考图缩小回显在结果区顶部，提示「它只作风格参考、不决定版式」。</Term>
        <Term name="候选图">本次生成的成图，可单张下载，或用「下载全部」打包（含参考图与中间过程）。</Term>
        <Term name="检索参考">本次检索实际用到的范例图注列表（来自论文配图库）。</Term>
        <Term name="生成演化">从规划到精修的每一步过程与中间图，方便你理解模型「为什么这么画」。</Term>
      </div>

      <div className="guide-section">
        <h3><HelpCircle size={17} /> 提示与常见问题</h3>
        <ul className="guide-faq">
          <li>方法描述写得越具体（有哪些模块、先后/并列关系），出图越准。</li>
          <li>密钥只用于本次调用、不入库；建议用完在各平台控制台轮换。</li>
          <li>出图不理想：加大评审轮数、换更强的主/图像模型，或上传一张风格接近的参考图。</li>
          <li>某清晰度选不到：说明当前图像模型不支持，换支持的模型即可。</li>
          <li>任务记录页可回看历史任务与结果。</li>
        </ul>
      </div>

      <div className="guide-foot">
        还有疑问？<button type="button" className="guide-link" onClick={onContact}>扫码联系作者</button>，或点右下角「意见反馈」。
      </div>
    </section>
  );
}
