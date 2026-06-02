import { AlertTriangle, Loader2, Settings2 } from 'lucide-react';
import { formatConfigurationMode, formatErrorMessage, formatOutputFormat } from '../utils';
import ResultFigure from './ResultFigure';
import StatusBadge from './StatusBadge';

export default function JobStatus({ job, apiBase }) {
  if (!job) {
    return (
      <div className="empty-state">
        <Settings2 size={34} />
        <p>等待新任务</p>
      </div>
    );
  }

  return (
    <div className="job-detail">
      <div className="status-strip">
        <StatusBadge status={job.status} />
        <span>{formatConfigurationMode(job.configuration_mode)}</span>
        <span>{job.provider}</span>
        <span>{job.aspect_ratio}</span>
        <span>{formatOutputFormat(job.output_format)}</span>
        <span>{job.num_candidates} 张候选图</span>
      </div>
      {job.error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(job.error)}</div> : null}
      <div className="image-grid">
        {job.result_images.map((image) => (
          <ResultFigure key={image.filename} image={image} apiBase={apiBase} outputFormat={job.output_format} />
        ))}
      </div>
      {job.status === 'running' || job.status === 'queued' ? (
        <div className="running-line"><Loader2 className="spin" size={17} />生成中，页面会自动刷新。</div>
      ) : null}
      {job.status === 'failed' && job.logs_tail ? <pre className="logs">{job.logs_tail}</pre> : null}
    </div>
  );
}
