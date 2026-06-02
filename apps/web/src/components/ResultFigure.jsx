import { FileDown } from 'lucide-react';
import { resolveImageUrl } from '../utils';

export default function ResultFigure({ image, apiBase, labelPrefix = '候选图', outputFormat = '' }) {
  const url = resolveImageUrl(apiBase, image.url);
  const candidateNumber = Number(image.candidate_id ?? 0) + 1;
  const format = inferFormat(image.mime_type, outputFormat);
  const filename = `paperbanana-${labelPrefix === '结果图' ? 'result' : 'candidate'}-${candidateNumber}.${format}`;

  return (
    <figure>
      <img src={url} alt={`${labelPrefix} ${candidateNumber}`} loading="lazy" />
      <figcaption className="result-caption">
        <span>{labelPrefix} {candidateNumber} · {format.toUpperCase()}</span>
        {url ? (
          <a href={url} download={filename} target="_blank" rel="noreferrer" aria-label={`下载${labelPrefix} ${candidateNumber}`}>
            <FileDown size={15} />
            下载
          </a>
        ) : null}
      </figcaption>
    </figure>
  );
}

function inferFormat(mimeType = '', outputFormat = '') {
  if (outputFormat === 'svg' || mimeType.includes('svg')) return 'svg';
  if (mimeType.includes('jpeg') || mimeType.includes('jpg')) return 'jpg';
  if (mimeType.includes('webp')) return 'webp';
  return 'png';
}
