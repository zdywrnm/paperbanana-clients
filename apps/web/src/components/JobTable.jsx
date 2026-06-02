import { AlertTriangle } from 'lucide-react';
import { formatConfigurationMode, formatDate, formatErrorMessage, formatOutputFormat } from '../utils';
import ResultFigure from './ResultFigure';
import StatusBadge from './StatusBadge';

export default function JobTable({ jobs, showUser, apiBase }) {
  return (
    <div className="job-table">
      {!jobs.length ? <div className="job-empty">暂无任务记录</div> : null}
      {jobs.map((item) => (
        <div className="job-record-card" key={item.id}>
          <div className="job-record-topline">
            <div className="job-record-meta">
              <span>
                <strong>时间</strong>
                {formatDate(item.created_at || item.createdAt)}
              </span>
              <span>
                <strong>状态</strong>
                <StatusBadge status={item.status} />
              </span>
              <span>
                <strong>模式</strong>
                {formatConfigurationMode(item.configuration_mode)}
              </span>
              <span>
                <strong>类别</strong>
                {item.infographic_category || '方法框架图'}
              </span>
              <span>
                <strong>格式</strong>
                {formatOutputFormat(item.output_format)}
              </span>
              {showUser ? (
                <span>
                  <strong>用户</strong>
                  <span title={item.user_email}>{item.user_email || '匿名'}</span>
                </span>
              ) : null}
            </div>
          </div>

          <div className="job-models">
            <div>
              <strong>主模型</strong>
              <span title={item.main_model_name}>{item.main_model_name || '未记录'}</span>
            </div>
            <div>
              <strong>图像生成模型</strong>
              <span title={item.image_gen_model_name}>{item.image_gen_model_name || '未记录'}</span>
            </div>
          </div>

          <div className="job-prompts">
            <div>
              <strong>论文方法内容</strong>
              <p>{item.method_content || '未记录'}</p>
            </div>
            <div>
              <strong>目标图注</strong>
              <p>{item.caption || '未记录'}</p>
            </div>
          </div>

          {item.status === 'failed' && item.error ? (
            <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(item.error)}</div>
          ) : null}

          {item.status === 'succeeded' && (item.result_images || []).some((image) => image.url) ? (
            <div className="job-record-images">
              {(item.result_images || []).filter((image) => image.url).map((image) => (
                <ResultFigure key={image.filename} image={image} apiBase={apiBase} labelPrefix="结果图" outputFormat={item.output_format} />
              ))}
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}
