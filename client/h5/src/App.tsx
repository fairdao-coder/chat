import { useEffect, useRef, useState, type ReactNode } from 'react';
import Login from './components/Login';
import ConversationList from './components/ConversationList';
import ChatWindow from './components/ChatWindow';
import Contacts from './components/Contacts';
import { ChatIcon } from './components/Icons';
import {
  clearAuth,
  getConversations,
  getGroupMessages,
  getMe,
  getPrivateMessages,
  getToken,
} from './api';
import {
  disconnect,
  ensureConnected,
  joinGroup,
  onReceiveMessage,
  onUserOffline,
  onUserOnline,
  sendGroupMessage,
  sendPrivateMessage,
} from './signalr';
import { groupConvId, privateConvId } from './util';
import type { ContactDto, MessageDto, UserDto } from './types';

function useIsWide() {
  const [wide, setWide] = useState(
    () => typeof window !== 'undefined' && window.innerWidth >= 860,
  );
  useEffect(() => {
    const onResize = () => setWide(window.innerWidth >= 860);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);
  return wide;
}

function getInitialTheme(): 'light' | 'dark' {
  const saved = localStorage.getItem('theme');
  if (saved === 'light' || saved === 'dark') return saved;
  if (
    typeof window !== 'undefined' &&
    window.matchMedia &&
    window.matchMedia('(prefers-color-scheme: dark)').matches
  ) {
    return 'dark';
  }
  return 'light';
}

function lastPreview(m: MessageDto): string {
  if (m.type === 'Image') return '[图片]';
  if (m.type === 'File') return '[文件]';
  return m.content;
}

export default function App() {
  const [me, setMe] = useState<UserDto | null>(null);
  const [contacts, setContacts] = useState<ContactDto[]>([]);
  const [selected, setSelected] = useState<ContactDto | null>(null);
  const [messages, setMessages] = useState<MessageDto[]>([]);
  const [online, setOnline] = useState<Set<string>>(new Set());
  const [showContacts, setShowContacts] = useState(false);
  const [theme, setTheme] = useState<'light' | 'dark'>(getInitialTheme);

  const meRef = useRef<UserDto | null>(null);
  const selectedRef = useRef<ContactDto | null>(null);
  const contactsRef = useRef<ContactDto[]>([]);
  const inited = useRef(false);

  useEffect(() => {
    meRef.current = me;
  }, [me]);
  useEffect(() => {
    selectedRef.current = selected;
  }, [selected]);
  useEffect(() => {
    contactsRef.current = contacts;
  }, [contacts]);

  // initial boot if already logged in
  useEffect(() => {
    if (inited.current) return;
    inited.current = true;
    const user = getMe();
    if (user && getToken()) {
      void boot(user);
    }
  }, []);

  // apply theme to <html data-theme>
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  function toggleTheme() {
    setTheme((t) => (t === 'dark' ? 'light' : 'dark'));
  }

  // register SignalR listeners once
  useEffect(() => {
    const offRecv = onReceiveMessage((msg: MessageDto) => {
      const meId = meRef.current?.id;
      const sel = selectedRef.current;
      if (meId && sel) {
        const matches = sel.isGroup
          ? msg.chatType === 'Group' && msg.conversationId === groupConvId(sel.id)
          : msg.chatType === 'Private' &&
            msg.conversationId === privateConvId(meId, sel.id);
        if (matches) {
          setMessages((prev) =>
            prev.some((m) => m.id === msg.id) ? prev : [...prev, msg],
          );
        }
      }

      // update the matching conversation's last message
      let matched = false;
      setContacts((prev) => {
        const next = prev.map((c) => {
          const match = c.isGroup
            ? msg.chatType === 'Group' && groupConvId(c.id) === msg.conversationId
            : msg.chatType === 'Private' &&
              meId != null &&
              privateConvId(c.id, meId) === msg.conversationId;
          if (match) {
            matched = true;
            return {
              ...c,
              lastMessage: lastPreview(msg),
              lastMessageAt: msg.createdAt,
            };
          }
          return c;
        });
        return sortContacts(next);
      });
      if (!matched) {
        // a message for an unknown conversation — refresh the list
        void refreshConversations();
      }
    });

    const offOn = onUserOnline((userId: string) => {
      setOnline((prev) => new Set(prev).add(userId));
      setContacts((prev) =>
        prev.map((c) => (c.id === userId ? { ...c, isOnline: true } : c)),
      );
    });

    const offOff = onUserOffline((userId: string) => {
      setOnline((prev) => {
        const n = new Set(prev);
        n.delete(userId);
        return n;
      });
      setContacts((prev) =>
        prev.map((c) => (c.id === userId ? { ...c, isOnline: false } : c)),
      );
    });

    return () => {
      offRecv();
      offOn();
      offOff();
    };
  }, []);

  async function boot(user: UserDto) {
    setMe(user);
    try {
      await ensureConnected();
    } catch (e) {
      console.error('SignalR 连接失败', e);
    }
    await refreshConversations();
  }

  async function refreshConversations() {
    try {
      const list = await getConversations();
      const sorted = sortContacts(list);
      setContacts(sorted);
      contactsRef.current = sorted;
    } catch (e) {
      if (e instanceof Error && e.message.includes('401')) {
        handleLogout();
      }
    }
  }

  function sortContacts(list: ContactDto[]): ContactDto[] {
    return [...list].sort((a, b) => {
      const ta = a.lastMessageAt ? new Date(a.lastMessageAt).getTime() : 0;
      const tb = b.lastMessageAt ? new Date(b.lastMessageAt).getTime() : 0;
      return tb - ta;
    });
  }

  async function handleLogin(user: UserDto) {
    await boot(user);
  }

  function handleLogout() {
    disconnect();
    clearAuth();
    setMe(null);
    setContacts([]);
    setSelected(null);
    setMessages([]);
    setOnline(new Set());
    setShowContacts(false);
  }

  async function openConversation(c: ContactDto) {
    setSelected(c);
    setShowContacts(false);
    setMessages([]);
    try {
      if (c.isGroup) {
        await joinGroup(c.id);
        const msgs = await getGroupMessages(c.id);
        setMessages(msgs);
      } else {
        const msgs = await getPrivateMessages(c.id);
        setMessages(msgs);
      }
    } catch (e) {
      console.error('加载历史失败', e);
    }
  }

  async function handleSend(
    content: string,
    type: 'Text' | 'Image' | 'File',
    mediaUrl?: string,
  ) {
    const sel = selectedRef.current;
    if (!sel) return;
    try {
      if (sel.isGroup) {
        await sendGroupMessage(sel.id, content, type, mediaUrl);
      } else {
        await sendPrivateMessage(sel.id, content, type, mediaUrl);
      }
      // server echoes ReceiveMessage to sender; appended via listener.
    } catch (e) {
      alert(e instanceof Error ? e.message : '发送失败');
    }
  }

  const selectedId = selected ? selected.id : undefined;
  const isWide = useIsWide();

  if (!me) {
    return (
      <div className="auth-shell">
        <Login onSuccess={handleLogin} />
      </div>
    );
  }

  // Desktop / tablet: persistent two-pane layout
  if (isWide) {
    return (
      <div className="app">
        <div className="desktop-window">
          <aside className="pane-side">
            <ConversationList
              contacts={contacts}
              selectedId={selectedId}
              online={online}
              theme={theme}
              onToggleTheme={toggleTheme}
              onSelect={openConversation}
              onRefresh={refreshConversations}
              onOpenContacts={() => setShowContacts(true)}
              onLogout={handleLogout}
            />
          </aside>
          <main className="pane-main">
            {showContacts ? (
              <Contacts
                onClose={() => setShowContacts(false)}
                onConversationsChanged={refreshConversations}
              />
            ) : selected ? (
              <ChatWindow
                contact={selected}
                messages={messages}
                me={me}
                meId={me.id}
                online={online}
                theme={theme}
                onToggleTheme={toggleTheme}
                onSend={handleSend}
                onBack={() => setSelected(null)}
              />
            ) : (
              <div className="empty-home">
                <ChatIcon size={64} />
                <p>选择一个会话，开始聊天</p>
              </div>
            )}
          </main>
        </div>
      </div>
    );
  }

  // Mobile: single pane with overlays
  let body: ReactNode;
  if (showContacts) {
    body = (
      <Contacts
        onClose={() => setShowContacts(false)}
        onConversationsChanged={refreshConversations}
      />
    );
  } else if (selected) {
    body = (
      <ChatWindow
        contact={selected}
        messages={messages}
        me={me}
        meId={me.id}
        online={online}
        theme={theme}
        onToggleTheme={toggleTheme}
        onSend={handleSend}
        onBack={() => setSelected(null)}
      />
    );
  } else {
    body = (
      <ConversationList
        contacts={contacts}
        selectedId={selectedId}
        online={online}
        theme={theme}
        onToggleTheme={toggleTheme}
        onSelect={openConversation}
        onRefresh={refreshConversations}
        onOpenContacts={() => setShowContacts(true)}
        onLogout={handleLogout}
      />
    );
  }

  return (
    <div className="app">
      <div className="mobile-frame">{body}</div>
    </div>
  );
}
