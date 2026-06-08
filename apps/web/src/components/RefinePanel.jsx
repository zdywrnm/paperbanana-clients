import { AlertTriangle, ImagePlus, Loader2, Send } from 'lucide-react';
import { formatErrorMessage } from '../utils';
import JobStatus from './JobStatus';
import Select from './Select';

export default function RefinePanel({
  sourceUrl,
  instruction,
  imageSize,
  aspectRatio,
  canSubmit,
  isSubmitting,
  error,
  job,
  apiBase,
  onSourceUrlChange,
  onInstructionChange,
  onImageSizeChange,
  onAspectRatioChange,
  onSubmit,
}) {
  return (
    <section className="refine-panel">
      <form className="refine-form" onSubmit={onSubmit}>
        <div className="section-head">
          <ImagePlus size={20} />
          <div>
            <h2>精修图片</h2>
            <p>上传结果图 URL 或从生成结果带入图片，再描述需要调整的内容。</p>
          </div>
        </div>
        <label className="field">
          <span>源图片 URL</span>
          <input value={sourceUrl} onChange={(event) => onSourceUrlChange(event.target.value)} placeholder="https://... 或 data:image/..." />
        </label>
        <label className="field">
          <span>精修指令</span>
          <textarea value={instruction} onChange={(event) => onInstructionChange(event.target.value)} rows={8} placeholder="例如：放大标签、减少装饰、让流程箭头更清晰。" />
        </label>
        <div className="settings-grid">
          <Select label="目标比例" value={aspectRatio} onChange={onAspectRatioChange} options={[
            ['16:9', '16:9'],
            ['21:9', '21:9'],
            ['3:2', '3:2'],
            ['1:1', '1:1'],
          ]} />
          <Select label="清晰度" value={imageSize} onChange={onImageSizeChange} options={[
            ['2K', '2K'],
            ['4K', '4K'],
          ]} />
        </div>
        <button className="primary-button" type="submit" disabled={!canSubmit}>
          {isSubmitting ? <Loader2 className="spin" size={18} /> : <Send size={18} />}
          提交精修
        </button>
        {error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(error)}</div> : null}
      </form>
      <div className="refine-result">
        <JobStatus job={job} apiBase={apiBase} />
      </div>
    </section>
  );
}
