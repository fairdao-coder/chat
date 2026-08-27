import * as signalR from '@microsoft/signalr';
import { API_BASE } from './config';
import { getToken } from './api';
import type { MessageDto } from './types';

type ReceiveHandler = (msg: MessageDto) => void;
type PresenceHandler = (userId: string) => void;

let connection: signalR.HubConnection | null = null;

const receiveHandlers = new Set<ReceiveHandler>();
const onlineHandlers = new Set<PresenceHandler>();
const offlineHandlers = new Set<PresenceHandler>();

export function getConnection(): signalR.HubConnection | null {
  return connection;
}

export function onReceiveMessage(handler: ReceiveHandler): () => void {
  receiveHandlers.add(handler);
  return () => receiveHandlers.delete(handler);
}

export function onUserOnline(handler: PresenceHandler): () => void {
  onlineHandlers.add(handler);
  return () => onlineHandlers.delete(handler);
}

export function onUserOffline(handler: PresenceHandler): () => void {
  offlineHandlers.add(handler);
  return () => offlineHandlers.delete(handler);
}

async function buildConnection(): Promise<signalR.HubConnection> {
  const token = getToken();
  const conn = new signalR.HubConnectionBuilder()
    .withUrl(`${API_BASE}/hubs/chat`, {
      accessTokenFactory: () => Promise.resolve(getToken() ?? token ?? ''),
    })
    .withAutomaticReconnect()
    .configureLogging(signalR.LogLevel.Warning)
    .build();

  conn.on('ReceiveMessage', (msg: MessageDto) => {
    receiveHandlers.forEach((h) => h(msg));
  });
  conn.on('UserOnline', (userId: string) => {
    onlineHandlers.forEach((h) => h(userId));
  });
  conn.on('UserOffline', (userId: string) => {
    offlineHandlers.forEach((h) => h(userId));
  });

  return conn;
}

export async function ensureConnected(): Promise<signalR.HubConnection> {
  if (connection && connection.state === signalR.HubConnectionState.Connected) {
    return connection;
  }
  if (!connection) {
    connection = await buildConnection();
  }
  if (connection.state === signalR.HubConnectionState.Disconnected) {
    await connection.start();
  }
  return connection;
}

export function disconnect(): void {
  if (connection) {
    connection.stop().catch(() => undefined);
    connection = null;
  }
}

// ----- send helpers -----

export async function sendPrivateMessage(
  toUserId: string,
  content: string,
  type: 'Text' | 'Image' | 'File' = 'Text',
  mediaUrl?: string,
): Promise<void> {
  const conn = await ensureConnected();
  await conn.invoke('SendPrivateMessage', toUserId, content, type, mediaUrl ?? null);
}

export async function sendGroupMessage(
  groupId: string,
  content: string,
  type: 'Text' | 'Image' | 'File' = 'Text',
  mediaUrl?: string,
): Promise<void> {
  const conn = await ensureConnected();
  await conn.invoke('SendGroupMessage', groupId, content, type, mediaUrl ?? null);
}

export async function joinGroup(groupId: string): Promise<void> {
  const conn = await ensureConnected();
  await conn.invoke('JoinGroup', groupId);
}

export async function leaveGroup(groupId: string): Promise<void> {
  const conn = await ensureConnected();
  await conn.invoke('LeaveGroup', groupId);
}
