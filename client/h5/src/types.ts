// DTO definitions mirroring the server contract in ARCHITECTURE.md.

export type ChatType = 'Private' | 'Group';
export type MessageType = 'Text' | 'Image' | 'File';

export interface UserDto {
  id: string;
  userName: string;
  nickName?: string;
  avatarUrl?: string;
  isOnline: boolean;
  lastSeenAt?: string | null;
}

export interface MessageDto {
  id: string;
  conversationId: string;
  senderId: string;
  senderName?: string;
  senderAvatar?: string | null;
  chatType: ChatType;
  content: string;
  type: MessageType;
  mediaUrl?: string | null;
  createdAt: string;
}

export interface GroupDto {
  id: string;
  name: string;
  avatarUrl?: string | null;
  memberCount: number;
  createdAt?: string;
}

export interface ContactDto {
  id: string;
  name: string;
  avatarUrl?: string | null;
  isOnline: boolean;
  lastMessage?: string | null;
  lastMessageAt?: string | null;
  isGroup: boolean;
}

export interface AuthResult {
  token: string;
  user: UserDto;
}

export interface FileUploadResult {
  url: string;
  contentType: string;
  size: number;
}
