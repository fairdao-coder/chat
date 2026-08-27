import { API_BASE } from './config';
import type { ContactDto, MessageDto } from './types';

// Private conversation id per contract: p_{guidA}_{guidB} (sorted ascending).
export function privateConvId(a: string, b: string): string {
  return `p_${[a, b].sort().join('_')}`;
}

export function groupConvId(groupId: string): string {
  return `g_${groupId}`;
}

// Resolve a media url returned by the server (e.g. "/files/xxx.png") against API base.
export function mediaUrl(url?: string | null): string {
  if (!url) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return `${API_BASE}${url}`;
}

export function findContactByConvId(
  contacts: ContactDto[],
  msg: MessageDto,
  meId: string,
): ContactDto | undefined {
  if (msg.chatType === 'Group') {
    const groupId = msg.conversationId.startsWith('g_')
      ? msg.conversationId.slice(2)
      : '';
    return contacts.find((c) => c.isGroup && c.id === groupId);
  }
  // private: conversationId is p_{a}_{b}
  return contacts.find(
    (c) => !c.isGroup && msg.conversationId === privateConvId(c.id, meId),
  );
}

// Deterministic pleasant color from a seed string (for avatar fallbacks).
export function avatarColor(seed: string): string {
  let h = 0;
  for (let i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  }
  const hue = h % 360;
  return `hsl(${hue} 58% 56%)`;
}

// Compact relative time for conversation list / message timestamps.
export function formatTime(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfThat = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dayDiff = Math.round(
    (startOfToday.getTime() - startOfThat.getTime()) / 86400000,
  );
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  if (dayDiff === 0) return `${hh}:${mm}`;
  if (dayDiff === 1) return `昨天 ${hh}:${mm}`;
  if (dayDiff > 1 && dayDiff < 7)
    return `${['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()]} ${hh}:${mm}`;
  return `${d.getMonth() + 1}月${d.getDate()}日 ${hh}:${mm}`;
}

// Human day label used inside chat as a date divider.
export function formatDay(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfThat = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dayDiff = Math.round(
    (startOfToday.getTime() - startOfThat.getTime()) / 86400000,
  );
  if (dayDiff === 0) return '今天';
  if (dayDiff === 1) return '昨天';
  if (dayDiff > 1 && dayDiff < 7)
    return ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()];
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
}
