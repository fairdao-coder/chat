# ChatSystem — WeChat-like Real-time Messaging System

A fully **decoupled front-end / back-end** WeChat-like messaging system:

- **Server**: ASP.NET Core 10 + SignalR (WebSocket) + PostgreSQL + JWT authentication
- **Client**: Flutter (`client/flutter_chat`), supporting Web / Android / iOS
- **Admin**: Flutter (`client/flutter_admin`), supporting Web / Android / iOS

The server API contract and SignalR protocol are the authoritative source in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); client usage help is in [`docs/HELP.md`](docs/HELP.md).

---

## Feature Scope (MVP)

- Account registration / login (JWT, `Bearer` auth)
- Friends: search users, send / accept friend requests, friend list
- Groups: create groups, my group list
- Conversations: conversation list (with last message, unread count, online status)
- Real-time messaging: SignalR-based private / group chat, real-time send/receive + online / offline status push
- Images / files: upload then send; images display inline, files provide a download link

---

## Directory Structure

```
chat/
├── server/                 # ASP.NET Core 10 server
│   ├── ChatServer/         # Main API + SignalR Hub (Controllers / Hubs / Services / Entities / Data)
│   ├── AdminServer/        # Admin API
│   └── docker-compose.yml  # One-click PostgreSQL
├── client/
│   ├── flutter_chat/       # User client (Flutter, build-verified)
│   └── flutter_admin/      # Admin client (Flutter, build-verified)
└── docs/
    ├── ARCHITECTURE.md     # API / protocol contract (authoritative)
    └── HELP.md             # Client usage help
```

---

## 1. Start the Server

### Prerequisites
- .NET 10 SDK
- PostgreSQL (Docker one-click startup recommended)

### Start the Database
```bash
cd server
docker compose up -d          # Start PostgreSQL (port 5432; db/user/password in docker-compose.yml)
```

### Configuration (Multi-environment)
Configuration is split by environment and switched via the `ASPNETCORE_ENVIRONMENT=Development|Production`
environment variable (default: Development). See each service's files:

- `appsettings.json` —— shared base configuration
- `appsettings.Development.json` —— development (localhost, dev key, permissive CORS)
- `appsettings.Production.json` —— production (**placeholder values — must be replaced or overridden via env vars before deploy**:
  `CONNECTIONSTRINGS__DEFAULT`, `Jwt__Key`, `SeedAdmin__Password`, etc.)

Common keys: `ConnectionStrings:Default` (PostgreSQL connection string), `Jwt:Key` (signing key),
`Urls` (listen address), `Cors:Origins` (allowed front-end origins).

### Run
```bash
cd server/ChatServer
dotnet run -c Release
# or publish
dotnet publish -c Release -o out
```
After startup:
- API base: `http://localhost:5298`
- Swagger docs: `http://localhost:5298/swagger`
- SignalR Hub: `http://localhost:5298/hubs/chat`
- Health check: `http://localhost:5298/health` (returns `Healthy` when process and DB are both fine)
- Static / uploaded files: `http://localhost:5298/files/...`

> EF Core auto-`EnsureCreated()` at startup (demo). For production, use migrations instead:
> `dotnet ef migrations add Init && dotnet ef database update`.

AdminServer is the same (`http://localhost:5299`, `/health` also available).

---

## 2. Flutter Client

Source is in `client/flutter_chat` (user client) and `client/flutter_admin` (admin client).

### Local Development
```bash
cd client/flutter_chat
flutter pub get
flutter run -d chrome      # Web
flutter run -d android     # Android device / emulator
```

Ways to set the API address (pick one):
- **Build time**: `flutter build web --dart-define=API_BASE=https://your.api`
- **Runtime**: override manually in the login page "Settings", or import via a config link (see `docs/HELP.md`)

### Build & Publish
Client build, Android APK per-architecture packaging, iOS build, and static site publishing are all done automatically by CI — see Section 4.
Client features (scan, config links, download page, etc.) are in [`docs/HELP.md`](docs/HELP.md).

---

## 3. API & Protocol Contract

REST APIs, the SignalR Hub protocol, and message structures follow [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Key endpoints at a glance:

- Auth: `POST /api/auth/register`, `POST /api/auth/login` (returns `token` + `user`)
- User / Friends: `GET /api/users/search`, `POST /api/friends/request`, `GET /api/friends`, etc.
- Groups / Conversations: `POST /api/groups`, `GET /api/conversations`
- Files: `POST /api/files/upload` (multipart, field `file`)
- Realtime: `/hubs/chat` (`SendPrivateMessage` / `SendGroupMessage` / `JoinGroup`; pushes `ReceiveMessage` / `UserOnline` / `UserOffline`)

All REST requests need `Authorization: Bearer <token>` in the header.

---

## 4. CI/CD & Front-end Static Publishing

`.github/workflows/ci-cd.yml` runs quality gates (.NET build + Flutter analyze) on push / PR,
and additionally builds the two Flutter Web apps **and Android APK** when pushing to `main`, publishing them together:

| Artifact | Publish path |
| --- | --- |
| `client/flutter_chat` (user client) | <https://servestatic.github.io/Chat/> |
| `client/flutter_admin` (admin client) | <https://servestatic.github.io/Chat/admin/> |
| Android APK download page | <https://servestatic.github.io/Chat/download/> |
| Config link generator | <https://servestatic.github.io/Chat/config/> |

The site is hosted on the `gh-pages` branch of the [`ServeStatic/Chat`](https://github.com/ServeStatic/Chat) repository.

### Android APK

Each deploy builds install packages **split by CPU architecture** (the universal package was removed because it exceeded GitHub's 100MB per-file limit):

| File | Description |
| --- | --- |
| `chat-arm64-v8a.apk` | Most modern phones, smallest size (recommended) |
| `chat-armeabi-v7a.apk` | Older 32-bit devices |
| `chat-x86_64.apk` | Emulators and some tablets |

The download page is generated by `.github/scripts/gen-download-page.sh`; each APK card embeds a QR code of its download URL,
and the footer additionally provides direct QR codes for "Chat app" and "Config generator".

#### About Signing

The release build is signed with the Flutter template's default debug key, so CI needs no keystore, but:
1. On install, Google Play Protect warns "Unknown publisher" — choose "Install anyway";
2. Changing the signing key prevents already-installed users from upgrading in place — they must uninstall first.

Before official release, define `signingConfigs.release` in `build.gradle.kts`, store the keystore as base64
in secrets (e.g. `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_*`), and decode it in the `build-android` job before building.

#### iOS Build (Optional Signing)

`build-ios` runs on a `macos-latest` runner (Xcode is macOS-only). By default it produces an **unsigned**
`Runner.app` (compile check only). When the following secrets are configured it automatically produces a **signed** `Runner.ipa`:

| Secret | Description |
| --- | --- |
| `IOS_DIST_CERT_BASE64` | Distribution cert p12, base64-encoded |
| `IOS_DIST_CERT_PASSWORD` | p12 password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision`, base64-encoded |
| `IOS_TEAM_ID` (optional) | Apple Team ID |

When secrets are not configured it falls back to an unsigned build and CI does not fail. `ExportOptions.plist` is at
`client/flutter_chat/ios/ExportOptions.plist`.

### One-time Setup

> The `gh-pages` branch is created automatically by the workflow on first deploy (force push) — no manual creation needed; but Pages settings
> only list existing branches, so "Enable Pages" must come after the first deploy.

1. **Deploy token**: generate a PAT with write (`repo` scope) access to `ServeStatic/Chat`, and add it in this repo's
   **Settings → Secrets and variables → Actions** as `SERVESTATIC_DEPLOY_TOKEN`.
2. **(Optional) Online API address**: in **Settings → Secrets and variables → Actions → Variables** add
   - `PUBLIC_API_BASE` —— user client API base (`--dart-define=API_BASE`)
   - `PUBLIC_ADMIN_API_BASE` —— admin client API base (`--dart-define=ADMIN_API_BASE`)
   - `PUBLIC_WEB_BASE` —— static site root, default `https://servestatic.github.io/Chat/`,
     affects the download-page QR code target (set for custom domains)

   If unset, the published build still connects to `http://localhost:5298 / :5299`; users can also override in "Settings".
3. **(Optional) Download page address**: if the static site and API are on different domains, inject
   `DOWNLOAD_URL` at build time (`--dart-define=DOWNLOAD_URL=https://example.com/download/`),
   and the login page's "Download client" button changes accordingly; it can also be pushed at runtime via a config link (see `docs/HELP.md`).
4. **Trigger first deploy**: push to `main` and wait for the `Deploy to ServeStatic/Chat` job to finish (the `gh-pages` branch appears only then).
5. **Enable Pages**: in `ServeStatic/Chat`'s **Settings → Pages** choose
   *Build and deployment → Source: Deploy from a branch*, branch `gh-pages`, directory `/ (root)`.

> Project page URLs are case-sensitive; `--base-href` uses `/Chat/`, `/Chat/admin/`; custom domains or org pages need `/`, `/admin/`.

### Client Features

- **Scan**: entry on the login page and "Discover" page; recognizes web links, config links (`fairchat://config`), and plain text.
- **Download page**: <https://servestatic.github.io/Chat/download/>, each architecture APK carries a QR code.
- **Config link generator**: <https://servestatic.github.io/Chat/config/>, visually generates `fairchat://config` links.

---

## 5. Known Limits & Future Extensions

- **Persistence**: PostgreSQL + EF Core; no message pagination cursor / read-receipt persistence (protocol reserves `ReadReceipt`).
- **Horizontal scaling**: SignalR single-node in-memory `PresenceTracker`; multi-instance needs Redis Backplane + external ID distribution.
- **Security**: JWT key and CORS are demo config — for production use strong keys, HTTPS, strict CORS, file validation, and virus scanning.
- **Push**: native clients in production should integrate FCM / APNs for offline push (SignalR is online-realtime only).
