# ChatSystem — 类微信实时通讯系统

一个**前后端完全分离**的类微信通讯系统：

- **服务端**：ASP.NET Core 10 + SignalR（WebSocket）+ PostgreSQL + JWT 鉴权
- **H5 网页端**：Vite + React + TypeScript + `@microsoft/signalr`（已构建通过，可直接运行）
- **安卓 / 苹果端**：.NET MAUI 单工程双目标（`net10.0-android` + `net10.0-ios`，共享 C# 逻辑与 XAML UI）

三个客户端共用**同一套 REST 接口契约 + SignalR Hub 协议**，详见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

---

## 功能范围（MVP）

- 账号注册 / 登录（JWT，`Bearer` 鉴权）
- 好友：搜索用户、发送 / 接受好友请求、好友列表
- 群组：创建群、我的群列表
- 会话：会话列表（含最后一条消息、未读数、在线状态）
- 实时通讯：基于 SignalR 的私聊 / 群聊，实时收发 + 在线 / 离线状态推送
- 图片 / 文件：上传后发送，图片内联显示、文件提供下载链接

---

## 目录结构

```
chat/
├── server/                 # ASP.NET Core 10 服务端
│   ├── ChatServer/         # 主工程（Controllers / Hubs / Services / Entities / Data）
│   └── docker-compose.yml  # 一键拉起 PostgreSQL
├── client/
│   ├── h5/                 # H5 网页端（React + Vite，已构建）
│   └── MauiChat/           # .NET MAUI 安卓/iOS 端（源码，需本地 MAUI 工作负载构建）
└── docs/
    └── ARCHITECTURE.md     # 接口 / 协议契约（权威）
```

---

## 1. 启动服务端

### 前置
- .NET 10 SDK（本工程在 .NET 10 上构建验证通过）
- PostgreSQL（推荐用 docker 一键启动）

### 启动数据库
```bash
cd server
docker compose up -d          # 启动 PostgreSQL（端口 5432，库名/账号/密码见 docker-compose.yml）
```

### 配置
编辑 `server/ChatServer/appsettings.json`：
- `ConnectionStrings:DefaultConnection`：PostgreSQL 连接串
- `Jwt:Key`：JWT 签名密钥（生产请替换为强随机值）
- `FileStorage:BaseUrl`：文件访问基址（默认 `http://localhost:5298`）

### 运行
```bash
cd server/ChatServer
dotnet run -c Release
# 或发布
dotnet publish -c Release -o out
```
启动后：
- API 基址：`http://localhost:5298`
- Swagger 文档：`http://localhost:5298/swagger`
- SignalR Hub：`http://localhost:5298/hubs/chat`
- 静态文件 / 上传文件：`http://localhost:5298/files/...`

> EF Core 在启动时自动 `EnsureCreated()` 建表（演示用）。生产建议改用迁移 `dotnet ef migrations add Init && dotnet ef database update`。

---

## 2. 运行 H5 网页端

```bash
cd client/h5
npm install                      # 已验证：依赖已安装
npm run dev                      # 开发服务器 http://localhost:5173
# 生产构建
npm run build && npm run preview
```
- 默认连接 `http://localhost:5298`（见 `src/config.ts`，可用 `.env` 的 `VITE_API_BASE` 覆盖）
- 浏览器打开 http://localhost:5173 → 注册两个账号 → 互加好友 → 实时聊天
- 响应式布局，可直接作为安卓 / 苹果 WebView 内核复用

---

## 3. 构建 .NET MAUI（安卓 / 苹果）

> 本工程为**完整源码**。由于 MAUI 需要平台工作负载与（iOS 还需）Mac，无法在此环境编译，请在本机按以下方式构建。

**Windows 构建安卓**：
1. 安装 Visual Studio 2022 17.8+，勾选“.NET MAUI 工作负载”（或 `dotnet workload install maui`）。
2. 安卓模拟器 / 真机需允许明文 HTTP：工程已设 `AndroidEnableCleartextTraffic=true`。
3. 把 `MauiChat/Config/AppConfig.cs` 里的 `ApiBase` 改成服务端地址
   - 安卓模拟器访问宿主机：`http://10.0.2.2:5298`
   - 真机 / iOS 模拟器：`http://<你的局域网IP>:5298`
4. 构建运行：
   ```bash
   cd client/MauiChat
   dotnet build -f net10.0-android
   dotnet build -t:Run -f net10.0-android -p:TargetFramework=net10.0-android
   ```

**macOS 构建 iOS**：
1. 在 Mac 上安装 VS Code / VS 2022 for Mac 或 `dotnet` + Xcode，并 `dotnet workload install maui`。
2. 配对 Mac 后：
   ```bash
   dotnet build -f net10.0-ios
   ```
3. iOS 模拟器可用 `http://localhost:5298`；真机用局域网 IP。

详见 `client/MauiChat/README.md`。

---

## 4. 接口速查（契约权威来源：`docs/ARCHITECTURE.md`）

### REST（均需在 Header 带 `Authorization: Bearer <token>`）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/auth/register` | 注册 |
| POST | `/api/auth/login` | 登录，返回 `token` + `user` |
| GET | `/api/users/search?q=` | 搜索用户 |
| POST | `/api/friends/request` | 发送好友请求（body = 对方 Guid 的 JSON 字符串） |
| GET | `/api/friends/requests` | 收到的好友请求 |
| POST | `/api/friends/accept` | 接受好友请求 |
| GET | `/api/friends` | 好友列表 |
| POST | `/api/groups` | 建群 `{name, memberIds}` |
| GET | `/api/groups` | 我的群 |
| GET | `/api/conversations` | 会话列表 |
| GET | `/api/messages/private/{friendId}` | 私聊历史 |
| GET | `/api/messages/group/{groupId}` | 群聊历史 |
| POST | `/api/files/upload` | 上传文件（multipart，字段 `file`） |

### SignalR Hub `/hubs/chat`
- 连接：`withUrl("<API_BASE>/hubs/chat", { accessTokenFactory: () => token })`（浏览器 WebSocket 走 query 的 `access_token`）
- 发送私聊：`SendPrivateMessage(toUserId, content, type, mediaUrl)` — `type ∈ {Text, Image, File}`
- 发送群聊：`SendGroupMessage(groupId, content, type, mediaUrl)`
- 加入群：`JoinGroup(groupId)`
- 服务端推送：`ReceiveMessage(message)`、`UserOnline(userId)`、`UserOffline(userId)`

---

## 5. CI/CD 与前端静态发布

`.github/workflows/ci-cd.yml` 在 push / PR 时跑质量门禁（.NET 构建 + Flutter analyze），
push 到 `main` 时额外构建两个 Flutter Web 应用并发布：

| 产物 | 发布路径 |
| --- | --- |
| `client/flutter_chat`（用户端） | <https://servestatic.github.io/Chat/> |
| `client/flutter_admin`（管理端） | <https://servestatic.github.io/Chat/admin/> |

站点托管在 [`ServeStatic/Chat`](https://github.com/ServeStatic/Chat) 仓库的 `gh-pages` 分支。
由于 `actions/deploy-pages` 只能发布到工作流所在的仓库，这里改为直接把构建产物推送到目标仓库。

### 一次性配置

> `gh-pages` 分支**不需要手动创建**。首次部署时 workflow 会用
> `git push --force ... HEAD:gh-pages` 自动在目标仓库建出该分支（即使是空仓库）。
> 但 Pages 设置的分支下拉框只列**已存在**的分支，所以第 3 步必须排在首次部署之后。

1. **创建 PAT**：生成一个对 `ServeStatic/Chat` 有写权限（`repo` scope）的 Personal Access Token，
   在本仓库 **Settings → Secrets and variables → Actions** 添加为 `SERVESTATIC_DEPLOY_TOKEN`。
2. **（可选）指定线上 API 地址**：在本仓库 **Settings → Secrets and variables → Actions → Variables** 添加
   - `PUBLIC_API_BASE` —— 注入 `AppConfig.defaultApiBase`（`--dart-define=API_BASE`）
   - `PUBLIC_ADMIN_API_BASE` —— 注入 `Constants.apiBaseUrl`（`--dart-define=ADMIN_API_BASE`）

   不设置的话，发布出去的页面仍会去连 `http://localhost:5298` / `:5299`。
   用户端也可在「设置」中手动覆盖 API 地址（存于 SharedPreferences）。
   建议在首次部署前设好，否则还要再部署一次才生效。
3. **触发首次部署**：push 到 `main`，等 `Deploy to ServeStatic/Chat` job 跑完。
   此时 `ServeStatic/Chat` 才出现 `gh-pages` 分支。
4. **开启 Pages**：在 `ServeStatic/Chat` 的 **Settings → Pages** 中选择
   *Build and deployment → Source: Deploy from a branch*，分支选 `gh-pages`、目录选 `/ (root)`。
   首次生效需等几十秒到几分钟。

> **注意**：项目页的 URL 路径大小写敏感，因此 `--base-href` 用的是 `/Chat/`、`/Chat/admin/`。
> 若改用自定义域或组织主页，需相应改为 `/`、`/admin/`。

---

## 6. 已知边界与后续扩展
- **持久化**：当前为内存友好型 PostgreSQL + EF Core，未做消息分页游标 / 已读回执落库（协议已预留 `ReadReceipt` 事件）。
- **水平扩展**：SignalR 目前为单机内存 `PresenceTracker`；多实例需接入 `Backplane`（Redis）+ 外部 ID 分发（如 Redis / 数据库序列）。
- **安全**：JWT 密钥与 CORS 为演示配置，生产请使用强密钥、HTTPS、严格 CORS 源、文件类型 / 大小校验与病毒扫描。
- **推送**：原生端生产建议接入 FCM / APNs 做离线推送（SignalR 仅在线实时通道）。
