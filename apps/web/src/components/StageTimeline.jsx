import { CheckCircle2, Image as ImageIcon, MessageSquareText } from 'lucide-react';
import { resolveImageUrl } from '../utils';

export default function StageTimeline({ job, apiBase }) {
  const stages = job?.stages || [];
  const references = job?.retrieved_references || [];
  if (!stages.length && !references.length) return null;

  return (
    <div className="stage-timeline">
      {references.length ? (
        <div className="retrieved-reference-strip">
          <strong>检索参考</strong>
          <div>
            {references.map((item) => (
              <span key={item.id} title={item.summary}>{item.title || item.id}</span>
            ))}
          </div>
        </div>
      ) : null}
      {stages.length ? (
        <>
          <strong className="stage-title">生成演化</strong>
          <div className="stage-list">
            {stages.map((stage, index) => (
              <article className="stage-item" key={stage.id || `${stage.type}-${index}`}>
                <div className="stage-marker">{stage.type === 'render' ? <ImageIcon size={15} /> : stage.type === 'critic' ? <MessageSquareText size={15} /> : <CheckCircle2 size={15} />}</div>
                <div className="stage-body">
                  <div className="stage-meta">
                    <strong>{stage.title || stage.type}</strong>
                    <span>候选 {Number(stage.candidate_id || 0) + 1}{stage.round ? ` · 第 ${stage.round} 轮` : ''}</span>
                  </div>
                  {stage.text ? <p>{stage.text}</p> : null}
                  {stage.image?.url ? <img src={resolveImageUrl(apiBase, stage.image.url)} alt={stage.title || '阶段图'} loading="lazy" /> : null}
                </div>
              </article>
            ))}
          </div>
        </>
      ) : null}
    </div>
  );
}
