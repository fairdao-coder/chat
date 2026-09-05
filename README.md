# ChatSystem — 类微信实时通讯系统

一个**前后端完全分离**的类微信通讯系统：

- **服务端**：ASP.NET Core 10 + SignalR（WebSocket）+ PostgreSQL + JWT 鉴权
- **用户端**：Flutter（`client/flutter_chat`），支持 Web / Android / iOS
- **管理端**：Flutter（`client/flutter_admin`），支持 Web / Android / iOS

服务端接口契约与 SignalR 协议以 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) 为权威来源；客户端使用帮助见 [`docs/HELP.md`](docs/HELP.md)。

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
│   ├── ChatServer/         # 主 API + SignalR Hub（Controllers / Hubs / Services / Entities / Data）
│   ├── AdminServer/        # 后台管理 API
│   └── docker-compose.yml  # 一键拉起 PostgreSQL
├── client/
│   ├── flutter_chat/       # 用户端（Flutter，已构建验证）
│   └── flutter_admin/      # 管理端（Flutter，已构建验证）
└── docs/
    ├── ARCHITECTURE.md     # 接口 / 协议契约（权威）
    └── HELP.md             # 客户端使用帮助
```

---

## 1. 启动服务端

### 前置
- .NET 10 SDK
- PostgreSQL（推荐用 docker 一键启动）

### 启动数据库
```bash
cd server
docker compose up -d          # 启动 PostgreSQL（端口 5432，库名/账号/密码见 docker-compose.yml）
```

### 配置（多环境）
配置按环境拆分，通过环境变量 `ASPNETCORE_ENVIRONMENT=Development|Production` 切换
（默认 Development）。详见各服务下的：

- `appsettings.json` —— 公共基础配置
- `appsettings.Development.json` —— 开发版（localhost、开发密钥、宽松 CORS）
- `appsettings.Production.json` —— 正式版（**占位值，部署前必须替换或用环境变量覆盖**：
  `CONNECTIONSTRINGS__DEFAULT`、`Jwt__Key`、`SeedAdmin__Password` 等）

常用配置键：`ConnectionStrings:Default`（PostgreSQL 连接串）、`Jwt:Key`（签名密钥）、
`Urls`（监听地址）、`Cors:Origins`（允许的前端来源）。

> **⚠️ 配置强校验（重构后行为变更）**：`Jwt:Key` 在非 `Development` 环境下缺失、仍含占位标记
> （`CHANGE` / `CHANGEME` / `PLEASECHANGEIT` / `DEVELOPMENTSECRET` / `YOUR_`）或长度不足 32 字符时，
> 进程会**启动即失败**（不再退回公开默认值）。请用如下命令生成并注入：
> ```bash
> openssl rand -base64 48      # 输出 ≥ 44 字符，直接作为 Jwt:Key
> # 环境变量覆盖（推荐）：Jwt__Key=<上面的输出>
> ```
> 同时 `Cors:Origins` 不再支持 `*` 通配，必须显式列出前端来源；缺失时拒绝跨域请求（开发环境仍宽松）。

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
- 健康检查：`http://localhost:5298/health`（返回 `Healthy` 表示进程与数据库均正常）
- 静态文件 / 上传文件：`http://localhost:5298/files/...`

> EF Core 在启动时自动 `EnsureCreated()` 建表（演示用）。生产建议改用迁移
> `dotnet ef migrations add Init && dotnet ef database update`。

AdminServer 同理（`http://localhost:5299`，`/health` 同样可用）。

---

## 2. Flutter 客户端

源码位于 `client/flutter_chat`（用户端）与 `client/flutter_admin`（管理端）。

### 本地开发
```bash
cd client/flutter_chat
flutter pub get
flutter run -d chrome      # 网页端
flutter run -d android     # 安卓真机 / 模拟器
```

API 地址设置方式（任选其一）：
- **构建期**：`flutter build web --dart-define=API_BASE=https://your.api`
- **运行期**：登录页「设置」中手动覆盖，或用配置链接一键导入（见 `docs/HELP.md`）

### 构建与发布
客户端构建、Android APK 拆分打包、iOS 构建与静态站点发布均由 CI 自动完成，详见第 4 节。
客户端功能（扫一扫、配置链接、下载页等）见 [`docs/HELP.md`](docs/HELP.md)。

---

## 3. 接口与协议契约

REST 接口、SignalR Hub 协议、消息结构等以 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) 为准。
关键端点速览：

- 认证：`POST /api/auth/register`、`POST /api/auth/login`（返回 `token` + `user`）
- 用户 / 好友：`GET /api/users/search`、`POST /api/friends/request`、`GET /api/friends` 等
- 群组 / 会话：`POST /api/groups`、`GET /api/conversations`
- 文件：`POST /api/files/upload`（multipart，字段 `file`）
- 实时：`/hubs/chat`（`SendPrivateMessage` / `SendGroupMessage` / `JoinGroup`；推送 `ReceiveMessage` / `UserOnline` / `UserOffline`）

所有 REST 请求需在 Header 带 `Authorization: Bearer <token>`。

---

## 4. CI/CD 与前端静态发布

`.github/workflows/ci-cd.yml` 在 push / PR 时跑质量门禁（.NET 构建 + Flutter analyze），
push 到 `main` 时额外构建两个 Flutter Web 应用 **和 Android APK**，合并后一起发布：

| 产物 | 发布路径 |
| --- | --- |
| `client/flutter_chat`（用户端） | <https://servestatic.github.io/Chat/> |
| `client/flutter_admin`（管理端） | <https://servestatic.github.io/Chat/admin/> |
| Android APK 下载页 | <https://servestatic.github.io/Chat/download/> |
| 配置链接生成器 | <https://servestatic.github.io/Chat/config/> |

站点托管在 [`ServeStatic/Chat`](https://github.com/ServeStatic/Chat) 仓库的 `gh-pages` 分支。

### Android APK

每次部署按 **CPU 架构拆分**构建安装包（universal 包因超 GitHub 单文件 100MB 限制已移除）：

| 文件 | 说明 |
| --- | --- |
| `chat-arm64-v8a.apk` | 绝大多数现代手机，体积最小（推荐） |
| `chat-armeabi-v7a.apk` | 较旧的 32 位设备 |
| `chat-x86_64.apk` | 模拟器与部分平板 |

下载页由 `.github/scripts/gen-download-page.sh` 生成，每个 APK 卡片内嵌其下载地址的二维码，
页尾另提供「聊天应用」「配置生成器」的直达二维码。

#### 关于签名

release 版使用 Flutter 模板默认的 debug key 签名，因此 CI 无需 keystore，但：
1. 安装时 Google Play 防护会提示「未知发布者」，需选「仍要安装」；
2. 更换签名 key 会导致已装用户无法覆盖升级，必须先卸载。

正式发布前建议在 `build.gradle.kts` 定义 `signingConfigs.release`，把 keystore 用 base64
存入 secret（如 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEY_*`），在 `build-android` job 解码后构建。

#### iOS 构建与 TestFlight 上传

`build-ios` 在 `macos-latest` runner 上运行（Xcode 仅 macOS 提供）。默认产出**未签名**的
`Runner.app`（仅编译检查）。

##### 已签名 IPA（可安装到设备）

当配置以下 secrets 时自动产出**已签名** `Runner.ipa`：

| Secret | 说明 |
| --- | --- |
| `IOS_DIST_CERT_BASE64` | 分发证书 p12，base64 编码 |
| `IOS_DIST_CERT_PASSWORD` | p12 密码 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision`，base64 编码（**TestFlight 须为 App Store Connect 类型**，非 Ad Hoc） |
| `IOS_TEAM_ID`（可选） | Apple Team ID |

未配置时自动回退未签名构建，CI 不失败。`ExportOptions.plist` 位于
`client/flutter_chat/ios/ExportOptions.plist`，其 `method` 已设为 `app-store`。

##### 上传到 TestFlight

在已签名基础上，再配置以下三项 App Store Connect API 密钥，CI 会自动把 IPA 上传到
App Store Connect（上传后在 TestFlight 建群即可）：

| Secret | 说明 |
| --- | --- |
| `IOS_APP_STORE_CONNECT_API_KEY_BASE64` | `AuthKey_XXXX.p8`，base64 编码 |
| `IOS_APP_STORE_CONNECT_KEY_ID` | API Key ID（10 位，如 `ABCD123456`） |
| `IOS_APP_STORE_CONNECT_ISSUER_ID` | Issuer ID（UUID） |

**如何获取 App Store Connect API 密钥：**
1. 登录 [App Store Connect](https://appstoreconnect.apple.com) → 用户和访问 → **集成** → App Store Connect API → 「+」新建（注意：密钥在「集成」标签下，不在「用户」标签）。
2. 选 **团队密钥**（非个人密钥）。
3. 权限选 **App 管理**（App Manager）；仅「开发者」权限无法上传 IPA。
4. 页面顶部 **Issuer ID**（UUID）即 `IOS_APP_STORE_CONNECT_ISSUER_ID`；新建后显示的 **Key ID** 即 `IOS_APP_STORE_CONNECT_KEY_ID`。
5. 点「下载 API 密钥」得到 `AuthKey_XXXX.p8`（**仅可下载一次**，请本地备份），base64 编码后填入 `IOS_APP_STORE_CONNECT_API_KEY_BASE64`：
   - macOS/Linux：`base64 -w0 AuthKey_XXXX.p8`
   - Windows PowerShell：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8"))`

### 一次性配置

> `gh-pages` 分支首次部署时由 workflow 自动创建（force push），无需手动建；但 Pages 设置
> 只列已存在分支，故「开启 Pages」须排在首次部署之后。

1. **部署令牌**：生成对 `ServeStatic/Chat` 有写权限（`repo` scope）的 PAT，在本仓库
   **Settings → Secrets and variables → Actions** 添加为 `SERVESTATIC_DEPLOY_TOKEN`。
2. **（可选）线上 API 地址**：在 **Settings → Secrets and variables → Actions → Variables** 添加
   - `PUBLIC_API_BASE` —— 用户端 API 基址（`--dart-define=API_BASE`）
   - `PUBLIC_ADMIN_API_BASE` —— 管理端 API 基址（`--dart-define=ADMIN_API_BASE`）
   - `PUBLIC_WEB_BASE` —— 静态站点根地址，默认 `https://servestatic.github.io/Chat/`，
     影响下载页二维码指向（自定义域名时设置）

   未设置则发布版仍连 `http://localhost:5298 / :5299`；用户也可在「设置」中手动覆盖。
3. **（可选）下载页地址**：若静态站点与 API 不同域，构建时注入
   `DOWNLOAD_URL`（`--dart-define=DOWNLOAD_URL=https://example.com/download/`），
   登录页「下载客户端」按钮会随之变化；亦可用配置链接在运行时下发（见 `docs/HELP.md`）。
4. **触发首次部署**：push 到 `main`，等 `Deploy to ServeStatic/Chat` job 完成（此时才出现 `gh-pages` 分支）。
5. **开启 Pages**：在 `ServeStatic/Chat` 的 **Settings → Pages** 选择
   *Build and deployment → Source: Deploy from a branch*，分支 `gh-pages`、目录 `/ (root)`。

> 项目页 URL 大小写敏感，`--base-href` 使用 `/Chat/`、`/Chat/admin/`；自定义域或组织主页需改为 `/`、`/admin/`。

### 客户端功能

- **扫一扫**：登录页与「发现」页入口，可识别网页链接、配置链接（`fairchat://config`）、纯文本。
- **下载页**：<https://servestatic.github.io/Chat/download/>，各架构 APK 带二维码。
- **配置链接生成器**：<https://servestatic.github.io/Chat/config/>，可视化生成 `fairchat://config` 链接。

---

## 5. 已知边界与后续扩展

- **持久化**：PostgreSQL + EF Core，未做消息分页游标 / 已读回执落库（协议已预留 `ReadReceipt`）。
  只读查询已统一加 `AsNoTracking`，会话列表 N+1 已压成少量批量查询。
- **水平扩展**：SignalR 单机内存 `PresenceTracker`；多实例需 Redis Backplane + 外部 ID 分发。
- **安全（已升级）**：
  - JWT 密钥启动期强校验（缺失 / 占位 / <32 字符则启动失败），CORS 不再回显任意 Origin；
  - 文件上传已加扩展名白名单 + 魔数嗅探 + 大小限制（`UploadSafety`），令牌签发收敛到 `TokenService` / `AdminTokenService`；
  - 认证 / 上传接口已启用限流（`RateLimitPolicies`）。生产仍建议叠加 HTTPS、文件病毒扫描与 WAF。
- **推送**：原生端生产建议接入 FCM / APNs 做离线推送（SignalR 仅在线实时通道）。

---

## 6. 服务端架构（重构后）

服务端已抽取共享类库 `server/Chat.Shared`，两个 Web 项目均引用之：

| 层 | 内容 |
| --- | --- |
| `Chat.Shared/Entities` | 公共实体（AppUser / Message / Friendship / Group / GroupMember / DiscoverColumn / SystemSettings / Enums），已删除两服务中的重复定义 |
| `Chat.Shared/Services` | `PasswordHasher`（定长安全比较）、`ConversationKeys` |
| `Chat.Shared/Security` | `JwtSettings`（强校验）、`AddJwtAuthentication` / `AddCorsPolicy` / `UploadSafety` / `RateLimitPolicies` |

`ChatServer` 业务逻辑已下沉到 `Services/`（`ConversationService` / `MessageService` / `FriendshipService` /
`CallCoordinator` / `PresenceTracker` / `FileStore`），`ChatHub` 与 `Controllers` 仅做协议转发。

完整接口 / 协议契约以 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) 为准。
