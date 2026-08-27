import { API_BASE } from './config';
import type {
  AuthResult,
  ContactDto,
  FileUploadResult,
  GroupDto,
  MessageDto,
  UserDto,
} from './types';

// ----- token helpers -----

const TOKEN_KEY = 'token';
const ME_KEY = 'me';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAuth(token: string, user: UserDto): void {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(ME_KEY, JSON.stringify(user));
}

export function clearAuth(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(ME_KEY);
}

export function getMe(): UserDto | null {
  const raw = localStorage.getItem(ME_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as UserDto;
  } catch {
    return null;
  }
}

// ----- low level -----

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
  isForm = false,
): Promise<T> {
  const headers: Record<string, string> = {};
  const token = getToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;

  let payload: BodyInit | undefined;
  if (body !== undefined) {
    if (isForm) {
      payload = body as FormData;
    } else {
      headers['Content-Type'] = 'application/json';
      payload = JSON.stringify(body);
    }
  }

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: payload,
  });

  if (!res.ok) {
    let message = `请求失败 (${res.status})`;
    try {
      const err = await res.json();
      if (err && typeof err === 'object' && 'message' in err) {
        message = String((err as { message: unknown }).message);
      } else if (typeof err === 'string') {
        message = err;
      }
    } catch {
      // ignore parse errors, keep default message
    }
    throw new Error(message);
  }

  if (res.status === 204) return undefined as T;
  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

// ----- auth -----

export function register(userName: string, password: string, nickName: string) {
  return request<AuthResult>('POST', '/api/auth/register', {
    userName,
    password,
    nickName,
  });
}

export function login(userName: string, password: string) {
  return request<AuthResult>('POST', '/api/auth/login', { userName, password });
}

// ----- users -----

export function searchUsers(q: string): Promise<UserDto[]> {
  return request<UserDto[]>('GET', `/api/users/search?q=${encodeURIComponent(q)}`);
}

export function getMeApi(): Promise<UserDto> {
  return request<UserDto>('GET', '/api/users/me');
}

// ----- friends -----

// body is the friend Guid as a JSON string, e.g. "\"uuid\""
export function sendFriendRequest(friendId: string): Promise<void> {
  return request<void>('POST', '/api/friends/request', JSON.stringify(friendId));
}

export function getFriendRequests(): Promise<UserDto[]> {
  return request<UserDto[]>('GET', '/api/friends/requests');
}

export function acceptFriendRequest(requesterId: string): Promise<void> {
  return request<void>('POST', '/api/friends/accept', JSON.stringify(requesterId));
}

export function getFriends(): Promise<UserDto[]> {
  return request<UserDto[]>('GET', '/api/friends');
}

export function deleteFriend(friendId: string): Promise<void> {
  return request<void>('DELETE', `/api/friends/${friendId}`);
}

// ----- groups -----

export function createGroup(name: string, memberIds: string[]): Promise<GroupDto> {
  return request<GroupDto>('POST', '/api/groups', { name, memberIds });
}

export function getGroups(): Promise<GroupDto[]> {
  return request<GroupDto[]>('GET', '/api/groups');
}

export function getGroup(id: string): Promise<GroupDto> {
  return request<GroupDto>('GET', `/api/groups/${id}`);
}

// ----- messages -----

export function getPrivateMessages(
  friendId: string,
  before?: string,
  count = 30,
): Promise<MessageDto[]> {
  const qs = new URLSearchParams({ count: String(count) });
  if (before) qs.set('before', before);
  return request<MessageDto[]>('GET', `/api/messages/private/${friendId}?${qs}`);
}

export function getGroupMessages(
  groupId: string,
  before?: string,
  count = 30,
): Promise<MessageDto[]> {
  const qs = new URLSearchParams({ count: String(count) });
  if (before) qs.set('before', before);
  return request<MessageDto[]>('GET', `/api/messages/group/${groupId}?${qs}`);
}

// ----- conversations -----

export function getConversations(): Promise<ContactDto[]> {
  return request<ContactDto[]>('GET', '/api/conversations');
}

// ----- files -----

export function uploadFile(file: File): Promise<FileUploadResult> {
  const form = new FormData();
  form.append('file', file);
  return request<FileUploadResult>('POST', '/api/files/upload', form, true);
}
