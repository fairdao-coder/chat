# 微信式通讯系统 — 架构与接口契约

> 目标：客户端（H5 / 安卓 / 苹果）与服务端**完全分离**，仅通过 **HTTP REST + WebSocket(SignalR)** 通信。
> 服务端：ASP.NET Core 10 + SignalR + PostgreSQL + JWT。
> 客户端：H5（Vite+React）、安卓/iOS（.NET MAUI，共享一套 C# 业务代码）。

---

## 1. 拓扑

```
┌──────────┐   ┌──────────┐   ┌──────────┐
│  H5(Web) │   │ Android  │   │   iOS    │   ← 客户端，互不直接通信
└────┬─────┘   └────┬─────┘   └────┬─────┘
     │  HTTPS / WS  │  HTTPS / WS  │  HTTPS / WS
     └──────────────┴──────┬───────┘
                            │
                   ┌────────▼─────────┐
                   │  ASP.NET Core 10  │
                   │  REST API         │  /api/...
                   │  SignalR Hub      │  /hubs/chat  (WebSocket)
                   │  Static Files     │  /files/...  (上传的媒体)
                   └────────┬─────────┘
                            │ EF Core
                   ┌────────▼─────────┐
                   │   PostgreSQL     │
                   └──────────────────┘
```

- 所有客户端共用同一套 REST 路径与 SignalR 事件名。
- 鉴权：JWT Bearer。REST 用 `Authorization: Bearer <token>` 头；SignalR 用 `access_token` 查询参数（WebSocket 握手时由客户端 `accessTokenProvider` 提供）。
- 服务端 CORS 默认放行 `http://localhost:5173`、`http://localhost:3000` 等开发源；生产请改 `Cors:Origins`。

---

## 2. REST 接口

基础地址：`http://localhost:5298`（开发）或 `http://localhost:8080`（docker）。下列路径均相对于该地址。

### 2.1 认证 `AuthController` (`/api/auth`)
| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | `/api/auth/register` | 否 | 注册，返回 token 与用户 |
| POST | `/api/auth/login` | 否 | 登录，返回 token 与用户 |

请求/响应（JSON）：
```
POST /api/auth/register
{ "userName": "alice", "password": "123456", "nickName": "Alice" }
→ 200 { "token": "...", "user": UserDto }

POST /api/auth/login
{ "userName": "alice", "password": "123456" }
→ 200 { "token": "...", "user": UserDto }
```

### 2.2 用户 `UsersController` (`/api/users`)
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/users/search?q=关键字` | 按用户名/昵称搜索（排除自己） |
| GET | `/api/users/me` | 当前登录用户 |

### 2.3 好友 `FriendsController` (`/api/friends`)
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/friends/request`  body:`"<friendId>"`(Guid) | 发送好友请求 |
| GET | `/api/friends/requests` | 我收到的待处理请求 |
| POST | `/api/friends/accept`  body:`"<friendId>"` | 接受某人的请求 |
| GET | `/api/friends` | 我的好友列表 |
| DELETE | `/api/friends/{friendId}` | 删除好友 |

### 2.4 群 `GroupsController` (`/api/groups`)
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/groups`  `{ "name": "群名", "memberIds": ["<guid>",...] }` | 建群（自动包含自己为 Owner） |
| GET | `/api/groups` | 我所在的群列表 |
| GET | `/api/groups/{id}` | 群详情 |

### 2.5 消息历史 `MessagesController` (`/api/messages`)
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/messages/private/{friendId}?before=ISO&count=30` | 与某好友的私聊历史（按时间升序） |
| GET | `/api/messages/group/{groupId}?before=ISO&count=30` | 群历史 |

### 2.6 会话列表 `ConversationsController` (`/api/conversations`)
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/conversations` | 返回好友+群，各带最后一条消息、在线状态、时间，按时间倒序 |

### 2.7 文件 `FilesController` (`/api/files`)
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/files/upload` (multipart/form-data, 字段名 `file`) | 上传图片/文件，返回 `{ "url": "/files/xxx.png", "contentType": "...", "size": 1234 }` |

---

## 3. SignalR Hub (`/hubs/chat`)

连接：`<base>/hubs/chat`，使用 JWT（`access_token` 查询参数）。连接成功后服务端会按用户所在群自动把连接加入对应 SignalR Group。

### 3.1 客户端 → 服务端（调用方法）
| 方法 | 参数 | 说明 |
|---|---|---|
| `SendPrivateMessage` | `(toUserId: string, content: string, type?: "Text"\|"Image"\|"File", mediaUrl?: string)` | 发私聊。需互为好友，否则 `HubException`。 |
| `SendGroupMessage` | `(groupId: string, content: string, type?: ..., mediaUrl?: string)` | 发群消息。需是群成员。 |
| `JoinGroup` | `(groupId: string)` | 把当前连接加入群频道（建群/加群后可选调用）。 |
| `LeaveGroup` | `(groupId: string)` | 退出群频道。 |

### 3.2 服务端 → 客户端（监听事件）
| 事件 | 载荷 | 说明 |
|---|---|---|
| `ReceiveMessage` | `MessageDto` | 收到新消息（私聊会同时推给发送者与接收者；群消息推给全群）。 |
| `UserOnline` | `string userId` | 某用户上线（MVP 广播给所有连接，客户端按通讯录过滤）。 |
| `UserOffline` | `string userId` | 某用户下线。 |

### 3.3 DTO 结构
```
UserDto      { id, userName, nickName, avatarUrl, isOnline, lastSeenAt }
MessageDto   { id, conversationId, senderId, senderName, senderAvatar,
               chatType: "Private"|"Group", content, type: "Text"|"Image"|"File",
               mediaUrl, createdAt }
GroupDto     { id, name, avatarUrl, memberCount, createdAt }
ContactDto   { id, name, avatarUrl, isOnline, lastMessage, lastMessageAt, isGroup }
AuthResult   { token, user: UserDto }
FileUploadResult { url, contentType, size }
```
> 枚举以字符串形式序列化（`JsonStringEnumConverter`）。时间均为 UTC ISO-8601。

---

## 4. 会话 ID 规则（客户端可本地推算，用于本地去重/历史拼接）
- 私聊：`p_{guidA}_{guidB}`（两个用户 ID 按字符串升序拼接）。
- 群聊：`g_{groupId}`。

---

## 5. 关键约定
1. 所有 REST 除注册/登录外都必须带 `Authorization: Bearer <token>`。
2. 文件先 `POST /api/files/upload` 拿到 `url`，再以 `type=Image/File` + `mediaUrl` 通过 SignalR 发送（文本则 `type=Text`、`mediaUrl=null`）。
3. 在线状态：客户端记录 `UserOnline/UserOffline` 事件维护内存在线集合，并与 `/api/conversations` 返回的 `isOnline` 合并。
4. 生产部署：修改 `Jwt:Key`（≥16 字节）、`Cors:Origins`、`ConnectionStrings:Default`，并关闭 Swagger（或加权限）。
