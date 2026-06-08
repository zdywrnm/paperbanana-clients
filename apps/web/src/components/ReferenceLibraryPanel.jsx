import { BookOpen, Loader2 } from 'lucide-react';

export default function ReferenceLibraryPanel({
  references,
  selectedIds,
  isLoading,
  error,
  onToggle,
  onRefresh,
}) {
  const selected = new Set(selectedIds);

  return (
    <div className="reference-library-panel">
      <div className="reference-library-head">
        <div>
          <strong><BookOpen size={15} /> 手动参考案例</strong>
          <span>从 PaperBanana 参考库选择最多 10 个案例。</span>
        </div>
        <button type="button" onClick={onRefresh} disabled={isLoading}>
          {isLoading ? <Loader2 className="spin" size={14} /> : null}
          刷新
        </button>
      </div>
      {error ? <p className="reference-upload-error">{error}</p> : null}
      <div className="reference-library-grid">
        {references.map((item) => (
          <button
            type="button"
            key={item.id}
            className={selected.has(item.id) ? 'reference-library-card active' : 'reference-library-card'}
            onClick={() => onToggle(item.id)}
          >
            {item.image_url ? <img src={item.image_url} alt={item.title} loading="lazy" /> : <span className="reference-card-placeholder">PB</span>}
            <strong>{item.title || item.id}</strong>
            <small>{item.summary || item.source}</small>
          </button>
        ))}
      </div>
      {!isLoading && !references.length ? <p className="reference-empty">参考库暂无数据，可先使用自动检索或上传参考图。</p> : null}
    </div>
  );
}
