import { useState } from 'react';
import { AlertTriangle, Loader2, ShieldCheck } from 'lucide-react';
import { authClient } from '../config';
import { formatErrorMessage } from '../utils';

export default function AuthPanel({ onAuthenticated, onCancel }) {
  const [mode, setMode] = useState('sign-in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isSignUp = mode === 'sign-up';

  async function submitAuth(event) {
    event.preventDefault();
    setError('');
    setIsSubmitting(true);
    try {
      const action = isSignUp
        ? authClient.signUp.email({
            email,
            password,
            name: name.trim() || email.split('@')[0] || 'PaperBanana 用户',
          })
        : authClient.signIn.email({ email, password });
      const { error: authError } = await action;
      if (authError) throw new Error(authError.message || '登录失败');
      await onAuthenticated();
    } catch (err) {
      setError(err.message);
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section className="auth-panel">
      <div className="section-head">
        <ShieldCheck size={22} />
        <div>
          <h2>{isSignUp ? '注册账号' : '登录账号'}</h2>
          <p>登录后可以在任务记录里查看历史结果，生成候选图仍可直接使用。</p>
        </div>
      </div>
      <form className="auth-form" onSubmit={submitAuth}>
        {isSignUp ? (
          <label className="field">
            <span>昵称</span>
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="可选" autoComplete="name" />
          </label>
        ) : null}
        <label className="field">
          <span>邮箱</span>
          <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" autoComplete="email" required />
        </label>
        <label className="field">
          <span>密码</span>
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="至少 8 位" autoComplete={isSignUp ? 'new-password' : 'current-password'} required />
        </label>
        <button className="primary-button" type="submit" disabled={isSubmitting || !email || password.length < 8}>
          {isSubmitting ? <Loader2 className="spin" size={18} /> : <ShieldCheck size={18} />}
          {isSignUp ? '注册并登录' : '登录'}
        </button>
        {error ? <div className="error-line"><AlertTriangle size={16} /> {formatErrorMessage(error)}</div> : null}
      </form>
      <button className="text-button" type="button" onClick={() => setMode(isSignUp ? 'sign-in' : 'sign-up')}>
        {isSignUp ? '已有账号，去登录' : '没有账号，去注册'}
      </button>
      {onCancel ? (
        <button className="text-button muted" type="button" onClick={onCancel}>暂不登录</button>
      ) : null}
    </section>
  );
}
