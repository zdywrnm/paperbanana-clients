import { CheckCircle2, XCircle } from 'lucide-react';
import { formatDate } from '../utils';

export default function AdminUsersTable({ users }) {
  return (
    <div className="admin-users-table">
      {!users.length ? <div className="job-empty">暂无账号记录</div> : null}
      {users.length ? (
        <>
          <div className="admin-users-head" aria-hidden="true">
            <span>账号</span>
            <span>注册时间</span>
            <span>最近登录</span>
            <span>状态</span>
            <span>用户 ID</span>
          </div>
          {users.map((user) => (
            <div className="admin-user-row" key={user.id || user.email}>
              <span>
                <strong title={user.email}>{user.email || '未记录邮箱'}</strong>
                <small title={user.name}>{user.name || '未填写昵称'}</small>
              </span>
              <span>{formatDate(user.created_at)}</span>
              <span>{formatDate(user.last_login_at || user.updated_at) || '暂无'}</span>
              <span>
                {user.email_verified ? <CheckCircle2 size={15} /> : <XCircle size={15} />}
                {user.email_verified ? '已验证' : '未验证'}
                <small>{user.session_count ? `${user.session_count} 个会话` : '无会话'}</small>
              </span>
              <span title={user.id}>{user.id || '未记录'}</span>
            </div>
          ))}
        </>
      ) : null}
    </div>
  );
}
