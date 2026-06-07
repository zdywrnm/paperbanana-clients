import { formatDate, formatFeedbackCategory } from '../utils';

export default function AdminFeedbackTable({ feedback }) {
  return (
    <div className="feedback-table">
      {!feedback.length ? <div className="job-empty">暂无反馈记录</div> : null}
      {feedback.map((item) => (
        <div className="feedback-record-card" key={item.id}>
          <div className="feedback-record-meta">
            <span>
              <strong>时间</strong>
              {formatDate(item.created_at)}
            </span>
            <span>
              <strong>类别</strong>
              {formatFeedbackCategory(item.category)}
            </span>
            <span>
              <strong>平台</strong>
              {item.platform || '未记录'}
            </span>
            <span>
              <strong>状态</strong>
              {item.status || 'new'}
            </span>
            <span>
              <strong>用户</strong>
              <span title={item.user_email || item.user_id}>{item.user_email || item.user_id || '匿名'}</span>
            </span>
            <span>
              <strong>联系方式</strong>
              <span title={item.contact}>{item.contact || '未留'}</span>
            </span>
          </div>

          <p className="feedback-message">{item.message}</p>

          <div className="feedback-context">
            <span title={item.job_id}>任务：{item.job_id || '无'}</span>
            <span title={item.client_version}>版本：{item.client_version || '未记录'}</span>
            <span title={item.client_ip}>IP：{item.client_ip || '未记录'}</span>
            <span title={item.user_agent}>UA：{item.user_agent || '未记录'}</span>
          </div>
        </div>
      ))}
    </div>
  );
}
