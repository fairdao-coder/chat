import { useRef, useState } from 'react';
import type { ContactDto, MessageDto, UserDto } from '../types';
import { mediaUrl, formatTime, formatDay } from '../util';
import { uploadFile } from '../api';
import Avatar from './Avatar';
import { BackIcon, ImageIcon, PaperclipIcon, SendIcon, SpinnerIcon, SunIcon, MoonIcon } from './Icons';

interface Props {
  contact: ContactDto;
  messages: MessageDto[];
  me: UserDto;
  meId: string;
  online: Set<string>;
  theme: 'light' | 'dark';
  onToggleTheme: () => void;
  onSend: (content: string, type: 'Text' | 'Image' | 'File', mediaUrl?: string) => void;
  onBack: () => void;
}

export default function ChatWindow({
  contact,
  messages,
  me,
  meId,
  online,
  theme,
  onToggleTheme,
  onSend,
  onBack,
}: Props) {
  const [text, setText] = useState('');
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const imageRef = useRef<HTMLInputElement>(null);

  const isOnline = !contact.isGroup && (online.has(contact.id) || contact.isOnline);

  async function handleSend() {
    const content = text.trim();
    if (!content) return;
    onSend(content, 'Text');
    setText('');
  }

  async function handlePick(e: React.ChangeEvent<HTMLInputElement>, isImage: boolean) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setUploading(true);
    try {
      const result = await uploadFile(file);
      onSend(file.name, isImage ? 'Image' : 'File', result.url);
    } catch (err) {
      alert(err instanceof Error ? err.message : '上传失败');
    } finally {
      setUploading(false);
    }
  }

  let prevDay = '';

  return (
    <div className="chat-window">
      <div className="chat-header">
        <button className="icon-btn back" onClick={onBack} title="返回">
          <BackIcon />
        </button>
        <div className="chat-title">
          <span>{contact.name}</span>
          {!contact.isGroup && (
            <span className={isOnline ? 'chat-sub on' : 'chat-sub'}>
              {isOnline ? '在线' : '离线'}
            </span>
          )}
          {contact.isGroup && <span className="chat-sub">群聊</span>}
        </div>
        <button
          className="icon-btn"
          title={theme === 'dark' ? '切换到白天' : '切换到黑夜'}
          onClick={onToggleTheme}
        >
          {theme === 'dark' ? <SunIcon /> : <MoonIcon />}
        </button>
      </div>

      <div className="messages">
        {messages.length === 0 && (
          <div className="empty">还没有消息，打个招呼吧 👋</div>
        )}
        {messages.map((m) => {
          const mine = m.senderId === meId;
          const day = formatDay(m.createdAt);
          const showDivider = day !== prevDay;
          prevDay = day;

          const avatarSrc = mine
            ? me.avatarUrl
            : contact.isGroup
              ? m.senderAvatar
              : contact.avatarUrl;
          const avatarName = mine
            ? me.nickName || me.userName
            : contact.isGroup
              ? m.senderName || '群友'
              : contact.name;

          return (
            <div key={`${day}-${m.id}`}>
              {showDivider && (
                <div className="day-divider">
                  <span>{day}</span>
                </div>
              )}
              <div className={mine ? 'msg-row mine' : 'msg-row'}>
                <Avatar src={avatarSrc} name={avatarName} size={38} />
                <div className="msg-col">
                  {!mine && contact.isGroup && (
                    <div className="msg-sender">{avatarName}</div>
                  )}
                  <div className="msg-bubble">
                    {m.type === 'Text' && <span>{m.content}</span>}
                    {m.type === 'Image' && (
                      <img
                        className="msg-img"
                        src={mediaUrl(m.mediaUrl)}
                        alt={m.content}
                      />
                    )}
                    {m.type === 'File' && (
                      <a
                        className="msg-file"
                        href={mediaUrl(m.mediaUrl)}
                        target="_blank"
                        rel="noreferrer"
                        download
                      >
                        <PaperclipIcon size={16} /> {m.content}
                      </a>
                    )}
                  </div>
                  <div className="msg-time">{formatTime(m.createdAt)}</div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="composer">
        <button
          className="icon-btn"
          title="发送图片"
          disabled={uploading}
          onClick={() => imageRef.current?.click()}
        >
          <ImageIcon />
        </button>
        <button
          className="icon-btn"
          title="发送文件"
          disabled={uploading}
          onClick={() => fileRef.current?.click()}
        >
          {uploading ? <SpinnerIcon size={18} /> : <PaperclipIcon />}
        </button>
        <input
          ref={imageRef}
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={(e) => handlePick(e, true)}
        />
        <input
          ref={fileRef}
          type="file"
          style={{ display: 'none' }}
          onChange={(e) => handlePick(e, false)}
        />
        <input
          className="composer-input"
          placeholder="输入消息…"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              handleSend();
            }
          }}
        />
        <button className="btn primary send" onClick={handleSend} disabled={!text.trim()}>
          <SendIcon size={16} /> 发送
        </button>
      </div>
    </div>
  );
}
