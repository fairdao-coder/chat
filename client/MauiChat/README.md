# MauiChat — .NET MAUI client for the WeChat-style chat system

A single shared C# codebase targeting **Android** and **iOS**, talking to the
already-built ASP.NET Core 10 + SignalR + PostgreSQL + JWT server described in
`docs/ARCHITECTURE.md`.

> This project was authored on a build box **without** the MAUI workload and
> **without** macOS, so it is delivered as source only. Follow the build steps
> below on a properly provisioned machine.

---

## 1. Prerequisites

### Windows (Android)
- **Visual Studio 2022 17.8+** with the **.NET MAUI** workload (or run
  `dotnet workload install maui` in a .NET 10 SDK).
- **Android SDK** (API 33/34+) and an emulator, or a physical device with USB
  debugging.
- The .NET 10 SDK.

### macOS (iOS)
- A Mac with **Xcode 15+** and the **.NET MAUI** workload
  (`dotnet workload install maui`).
- For developing on Windows, pair Visual Studio to the Mac (Tools → iOS →
  Pair to Mac), or build directly on the Mac.

### NuGet packages used (already referenced in `MauiChat.csproj`)
- `Microsoft.AspNetCore.SignalR.Client` — the realtime hub.
- `CommunityToolkit.Mvvm` — `ObservableObject` / `RelayCommand` / `[ObservableProperty]`.

---

## 2. Point the client at your server (`API_BASE`)

The base URL lives in `Config/AppConfig.cs` (`DefaultApiBase = "http://localhost:5298"`)
and is read by both the REST `ApiClient` and the `ChatHubClient` (`/hubs/chat`).

| Target                         | Value                          |
|--------------------------------|--------------------------------|
| Android emulator               | `http://10.0.2.2:5298`         |
| iOS simulator                  | `http://localhost:5298`        |
| Physical device (same LAN)     | `http://<your-dev-PC-IP>:5298` |

You can change it at compile time in `AppConfig.cs`, or persist an override at
runtime via `AppConfig.Set("http://10.0.2.2:5298")` (stored in `Preferences`).

> The server port must match what the ASP.NET Core app actually listens on
> (`:5298` in dev, `:8080` in the docker setup — see the architecture doc).

---

## 3. Run on Android

```bash
# From the repo root (client/MauiChat)
dotnet build -t:Run -f net10.0-android -p:AndroidDevice=emulator
# or deploy to a connected device:
dotnet build -t:Run -f net10.0-android
```

Or use Visual Studio: set the **MauiChat** project as startup, pick an Android
emulator, and press F5.

### Cleartext HTTP (dev only)
The dev server uses plain `http://`. The project already enables cleartext:
- Android: `<AndroidEnableCleartextTraffic>true</AndroidEnableCleartextTraffic>`
  in `MauiChat.csproj` (and `Platforms/Android/AndroidManifest.xml`).
- iOS: `NSAppTransportSecurity → NSAllowsLocalNetworking` in
  `Platforms/iOS/Info.plist`.
Remove/lock these down for production HTTPS.

---

## 4. Run on iOS

On a Mac:

```bash
dotnet build -t:Run -f net10.0-ios
```

On Windows with a paired Mac, build/deploy from Visual Studio (pick an iOS
simulator or a provisioned device). Real-device signing requires an Apple
Developer provisioning profile.

---

## 5. Solution structure

```
MauiChat/
├── MauiChat.csproj          # targets net10.0-android + net10.0-ios
├── MauiProgram.cs           # DI: HttpClient, ApiClient, AuthService, ChatHubClient, VMs
├── App.xaml(.cs)            # login-gate (starts at Login or AppShell by token)
├── AppShell.xaml(.cs)       # Shell with Contacts tab + routes: chat/addfriend/creategroup
├── Config/
│   ├── AppConfig.cs         # API_BASE + hub URL (overridable)
│   └── AuthKeys.cs          # SecureStorage keys
├── Models/                  # DTOs mirroring the contract (enums as strings)
│   ├── UserDto, MessageDto, GroupDto, ContactDto,
│   ├── AuthResult, FileUploadResult, FriendRequestDto, SelectableUser
│   └── Enums.cs             # ChatType ("Private"|"Group"), MessageType ("Text"|"Image"|"File")
├── Services/
│   ├── ApiClient.cs         # REST + JWT header + multipart upload
│   ├── AuthService.cs       # login/register + SecureStorage persistence
│   └── ChatHubClient.cs     # SignalR singleton wrapper (events + invokes)
├── ViewModels/              # CommunityToolkit.Mvvm
│   ├── LoginViewModel, ContactsViewModel, ChatViewModel,
│   ├── AddFriendViewModel, CreateGroupViewModel
├── Views/                   # XAML + code-behind
│   ├── LoginPage, ContactsPage, ChatPage, AddFriendPage, CreateGroupPage
├── Converters/              # Value converters (media URL, alignment, colors, …)
├── Resources/               # App icon / splash (SVG)
└── Platforms/              # Android + iOS entry points / manifests
```

---

## 6. Feature → contract mapping

| Feature | Endpoint / SignalR |
|---|---|
| Login / Register | `POST /api/auth/login`, `POST /api/auth/register` |
| Conversations | `GET /api/conversations` |
| Search users | `GET /api/users/search?q=` |
| Friend request | `POST /api/friends/request` (`"<guid>"` raw JSON) |
| Incoming requests | `GET /api/friends/requests` |
| Accept friend | `POST /api/friends/accept` (`"<guid>"` raw JSON) |
| Friends list | `GET /api/friends` |
| Create group | `POST /api/groups` (`{name, memberIds}`) |
| Groups list | `GET /api/groups` |
| Private history | `GET /api/messages/private/{friendId}` |
| Group history | `GET /api/messages/group/{groupId}` |
| Send private | `SendPrivateMessage(toUserId, content, type, mediaUrl)` |
| Send group | `SendGroupMessage(groupId, content, type, mediaUrl)` |
| Realtime | hub `/hubs/chat`; events `ReceiveMessage`, `UserOnline`, `UserOffline` |
| Upload | `POST /api/files/upload` (multipart field `file`) |
| Presence | `isOnline` from conversations + live `UserOnline`/`UserOffline` |

The JWT is sent as `Authorization: Bearer <token>` for REST and as the
`access_token` query parameter (via `AccessTokenProvider`) for SignalR.

---

## 7. Assumptions (verify against your server)

1. **`/api/friends/requests`** payload shape was not fully specified. We assume
   each request is `{ id, requesterId, requesterName, requestedAt }`
   (`Models/FriendRequestDto.cs`). Only `requesterId` is used by the accept call.
2. **`/api/friends`** is assumed to return `List<UserDto>`.
3. **`POST /api/groups`** response is not used by the client (we just navigate
   back to the contacts list).
4. The group **`ReceiveMessage`** filter relies on `conversationId == "g_{groupId}"`
   and private messages are additionally validated by participant ids, so the
   chat view stays correct even if the server's id formatting differs slightly.
5. The dev server URL is `http://localhost:5298` (change in `AppConfig.cs`).
