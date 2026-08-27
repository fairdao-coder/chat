import type { ContactDto } from '../types';
import { formatTime } from '../util';
import Avatar from './Avatar';
import { RefreshIcon, ContactsIcon, LogoutIcon, SunIcon, MoonIcon } from './Icons';

interface Props {
  contacts: ContactDto[];
  selectedId?: string;
  online: Set<string>;
  theme: 'light' | 'dark';
  onToggleTheme: () => void;
  onSelect: (c: ContactDto) => void;
  onRefresh: () => void;
  onOpenContacts: () => void;
  onLogout: () => void;
}

export default function ConversationList({
  contacts,
  selectedId,
  online,
  theme,
  onToggleTheme,
  onSelect,
  onRefresh,
  onOpenContacts,
  onLogout,
}: Props) {
  return (
    <div className="conv-list">
      <div className="conv-header">
        <span className="conv-title">微聊</span>
        <div className="conv-actions">
          <button
            className="icon-btn"
            title={theme === 'dark' ? '切换到白天' : '切换到黑夜'}
            onClick={onToggleTheme}
          >
            {theme === 'dark' ? <SunIcon /> : <MoonIcon />}
          </button>
          <button className="icon-btn" title="刷新" onClick={onRefresh}>
            <RefreshIcon />
          </button>
          <button className="icon-btn" title="通讯录" onClick={onOpenContacts}>
            <ContactsIcon />
          </button>
          <button className="icon-btn" title="退出登录" onClick={onLogout}>
            <LogoutIcon />
          </button>
        </div>
      </div>
      <div className="conv-items">
        {contacts.length === 0 && (
          <div className="empty">
            还没有会话
            <br />
            去通讯录加个好友或建个群吧
          </div>
        )}
        {contacts.map((c) => {
          const isOnline = c.isGroup ? false : online.has(c.id) || c.isOnline;
          return (
            <div
              key={c.id}
              className={c.id === selectedId ? 'conv-item active' : 'conv-item'}
              onClick={() => onSelect(c)}
            >
              <div className="avatar-wrap">
                <Avatar src={c.avatarUrl} name={c.name} size={46} />
                {!c.isGroup && (
                  <span
                    className={isOnline ? 'dot online' : 'dot offline'}
                    title={isOnline ? '在线' : '离线'}
                  />
                )}
              </div>
              <div className="conv-text">
                <div className="conv-name">
                  {c.isGroup ? '👥 ' : ''}
                  {c.name}
                </div>
                <div className="conv-last">{c.lastMessage || '暂无消息'}</div>
              </div>
              <div className="conv-meta">
                <div className="conv-time">{formatTime(c.lastMessageAt)}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
