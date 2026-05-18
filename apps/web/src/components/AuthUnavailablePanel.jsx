import { AlertTriangle, ShieldCheck } from 'lucide-react';

export default function AuthUnavailablePanel({ onCancel }) {
  return (
    <section className="auth-panel">
      <div className="section-head">
        <ShieldCheck size={22} />
        <div>
          <h2>账号登录</h2>
          <p>账号服务正在配置中。当前不登录也可以正常生成候选图。</p>
        </div>
      </div>
      <div className="login-required-card">
        <AlertTriangle size={22} />
        <div>
          <h3>登录注册暂未接入后端</h3>
          <p>部署 Better Auth 网关并配置认证地址后，这里会开放邮箱和密码登录注册。</p>
        </div>
      </div>
      <button className="text-button muted" type="button" onClick={onCancel}>返回生成候选图</button>
    </section>
  );
}
