import { useState } from 'react';
import {
  acceptFriendRequest,
  createGroup,
  getFriendRequests,
  getFriends,
  searchUsers,
  sendFriendRequest,
} from '../api';
import type { UserDto } from '../types';
import { joinGroup } from '../signalr';
import Avatar from './Avatar';
import { BackIcon, SearchIcon, CheckIcon } from './Icons';

interface Props {
  onClose: () => void;
  onConversationsChanged: () => void;
}

export default function Contacts({ onClose, onConversationsChanged }: Props) {
  const [tab, setTab] = useState<'search' | 'requests' | 'friends' | 'group'>(
    'search',
  );
  const [q, setQ] = useState('');
  const [results, setResults] = useState<UserDto[]>([]);
  const [requests, setRequests] = useState<UserDto[]>([]);
  const [friends, setFriends] = useState<UserDto[]>([]);
  const [groupName, setGroupName] = useState('');
  const [selectedMembers, setSelectedMembers] = useState<string[]>([]);
  const [msg, setMsg] = useState('');

  async function doSearch() {
    setMsg('');
    try {
      setResults(await searchUsers(q.trim()));
    } catch (e) {
      setMsg(e instanceof Error ? e.message : '搜索失败');
    }
  }

  async function loadRequests() {
    try {
      setRequests(await getFriendRequests());
    } catch {
      /* ignore */
    }
  }

  async function loadFriends() {
    try {
      setFriends(await getFriends());
    } catch {
      /* ignore */
    }
  }

  async function sendReq(id: string) {
    try {
      await sendFriendRequest(id);
      setMsg('好友请求已发送');
    } catch (e) {
      setMsg(e instanceof Error ? e.message : '发送失败');
    }
  }

  async function accept(id: string) {
    try {
      await acceptFriendRequest(id);
      setRequests((r) => r.filter((u) => u.id !== id));
      setMsg('已添加好友');
      onConversationsChanged();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : '接受失败');
    }
  }

  function toggleMember(id: string) {
    setSelectedMembers((s) =>
      s.includes(id) ? s.filter((x) => x !== id) : [...s, id],
    );
  }

  async function create() {
    if (!groupName.trim() || selectedMembers.length === 0) {
      setMsg('请填写群名并至少选择一名成员');
      return;
    }
    try {
      const g = await createGroup(groupName.trim(), selectedMembers);
      await joinGroup(g.id);
      setMsg('群已创建');
      setGroupName('');
      setSelectedMembers([]);
      onConversationsChanged();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : '创建失败');
    }
  }

  const tabLabel: Record<string, string> = {
    search: '找人',
    requests: '请求',
    friends: '好友',
    group: '建群',
  };

  return (
    <div className="contacts">
      <div className="contacts-header">
        <button className="icon-btn back" onClick={onClose} title="返回">
          <BackIcon />
        </button>
        <span className="contacts-title">通讯录</span>
      </div>

      <div className="segment">
        {(['search', 'requests', 'friends', 'group'] as const).map((t) => (
          <button
            key={t}
            className={tab === t ? 'active' : ''}
            onClick={() => {
              setTab(t);
              if (t === 'requests') loadRequests();
              if (t === 'friends' || t === 'group') loadFriends();
            }}
          >
            {tabLabel[t]}
          </button>
        ))}
      </div>

      {msg && <div className="hint">{msg}</div>}

      {tab === 'search' && (
        <div className="tab-body">
          <div className="search-row">
            <input
              className="input"
              placeholder="搜索用户名 / 昵称"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && doSearch()}
            />
            <button className="btn" onClick={doSearch}>
              <SearchIcon size={18} />
            </button>
          </div>
          {results.length === 0 && q && (
            <div className="empty">没有找到相关用户</div>
          )}
          {results.map((u) => (
            <div className="list-row" key={u.id}>
              <span className="lr-name">
                <Avatar src={u.avatarUrl} name={u.nickName || u.userName} size={36} />
                <span>{u.nickName || u.userName}</span>
              </span>
              <button className="btn small primary" onClick={() => sendReq(u.id)}>
                加好友
              </button>
            </div>
          ))}
        </div>
      )}

      {tab === 'requests' && (
        <div className="tab-body">
          {requests.length === 0 && <div className="empty">暂无好友请求</div>}
          {requests.map((u) => (
            <div className="list-row" key={u.id}>
              <span className="lr-name">
                <Avatar src={u.avatarUrl} name={u.nickName || u.userName} size={36} />
                <span>{u.nickName || u.userName}</span>
              </span>
              <button className="btn small primary" onClick={() => accept(u.id)}>
                <CheckIcon size={15} /> 接受
              </button>
            </div>
          ))}
        </div>
      )}

      {tab === 'friends' && (
        <div className="tab-body">
          {friends.length === 0 && <div className="empty">还没有好友</div>}
          {friends.map((u) => (
            <div className="list-row" key={u.id}>
              <span className="lr-name">
                <Avatar src={u.avatarUrl} name={u.nickName || u.userName} size={36} />
                <span>{u.nickName || u.userName}</span>
              </span>
              <span style={{ fontSize: 12, color: u.isOnline ? 'var(--green)' : 'var(--muted)' }}>
                {u.isOnline ? '在线' : '离线'}
              </span>
            </div>
          ))}
        </div>
      )}

      {tab === 'group' && (
        <div className="tab-body">
          <div className="field" style={{ marginBottom: 12 }}>
            <input
              className="input"
              placeholder="群名称"
              value={groupName}
              onChange={(e) => setGroupName(e.target.value)}
            />
          </div>
          <div className="section-label">选择成员（{selectedMembers.length}）</div>
          {friends.length === 0 && (
            <div className="empty">暂无好友，先去加好友</div>
          )}
          {friends.map((u) => (
            <label className="check-row" key={u.id}>
              <input
                type="checkbox"
                checked={selectedMembers.includes(u.id)}
                onChange={() => toggleMember(u.id)}
              />
              <Avatar src={u.avatarUrl} name={u.nickName || u.userName} size={32} />
              <span>{u.nickName || u.userName}</span>
            </label>
          ))}
          <button
            className="btn primary"
            style={{ marginTop: 12 }}
            onClick={create}
            disabled={!groupName.trim() || selectedMembers.length === 0}
          >
            创建群聊
          </button>
        </div>
      )}
    </div>
  );
}
