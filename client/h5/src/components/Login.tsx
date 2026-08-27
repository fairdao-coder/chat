import { useState } from 'react';
import { login, register, setAuth } from '../api';
import type { UserDto } from '../types';
import { ChatIcon, LockIcon, SpinnerIcon, UserIcon } from './Icons';

interface Props {
  onSuccess: (user: UserDto) => void;
}

export default function Login({ onSuccess }: Props) {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [userName, setUserName] = useState('');
  const [password, setPassword] = useState('');
  const [nickName, setNickName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit() {
    if (loading) return;
    if (!userName.trim() || !password) {
      setError('请输入用户名和密码');
      return;
    }
    setError('');
    setLoading(true);
    try {
      const result =
        mode === 'login'
          ? await login(userName.trim(), password)
          : await register(userName.trim(), password, nickName || userName.trim());
      setAuth(result.token, result.user);
      onSuccess(result.user);
    } catch (e) {
      setError(e instanceof Error ? e.message : '操作失败');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="brand">
          <div className="brand-logo">
            <ChatIcon size={32} />
          </div>
          <div className="brand-name">微聊</div>
          <div className="brand-slogan">让沟通更自由</div>
        </div>

        <div className="segment">
          <button
            className={mode === 'login' ? 'active' : ''}
            onClick={() => setMode('login')}
          >
            登录
          </button>
          <button
            className={mode === 'register' ? 'active' : ''}
            onClick={() => setMode('register')}
          >
            注册
          </button>
        </div>

        <div className="field">
          <UserIcon size={18} className="field-icon" />
          <input
            className="input"
            placeholder="用户名"
            value={userName}
            onChange={(e) => setUserName(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && submit()}
          />
        </div>
        <div className="field">
          <LockIcon size={18} className="field-icon" />
          <input
            className="input"
            type="password"
            placeholder="密码"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && submit()}
          />
        </div>
        {mode === 'register' && (
          <div className="field">
            <UserIcon size={18} className="field-icon" />
            <input
              className="input"
              placeholder="昵称（可选）"
              value={nickName}
              onChange={(e) => setNickName(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && submit()}
            />
          </div>
        )}

        {error && <div className="error">{error}</div>}

        <button className="btn-block" onClick={submit} disabled={loading}>
          {loading ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                justifyContent: 'center',
              }}
            >
              <SpinnerIcon size={16} /> 处理中…
            </span>
          ) : mode === 'login' ? (
            '登 录'
          ) : (
            '注 册'
          )}
        </button>

        <div className="login-foot">
          登录即表示同意 <a href="#" onClick={(e) => e.preventDefault()}>服务协议</a> 与
          <a href="#" onClick={(e) => e.preventDefault()}> 隐私政策</a>
        </div>
      </div>
    </div>
  );
}
