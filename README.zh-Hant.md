# ChatSystem — 類微信即時通訊系統

一個**前後端完全分離**的類微信通訊系統：

- **服務端**：ASP.NET Core 10 + SignalR（WebSocket）+ PostgreSQL + JWT 鑑權
- **用戶端**：Flutter（`client/flutter_chat`），支援 Web / Android / iOS
- **管理端**：Flutter（`client/flutter_admin`），支援 Web / Android / iOS

服務端介面契約與 SignalR 協議以 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) 為權威來源；客戶端使用幫助見 [`docs/HELP.md`](docs/HELP.md)。

---

## 功能範圍（MVP）

- 帳號註冊 / 登入（JWT，`Bearer` 鑑權）
- 好友：搜尋使用者、傳送 / 接受好友請求、好友清單
- 群組：建立群、我的群清單
- 會話：會話清單（含最後一則訊息、未讀數、線上狀態）
- 即時通訊：基於 SignalR 的私聊 / 群聊，即時收發 + 線上 / 離線狀態推送
- 圖片 / 檔案：上傳後傳送，圖片內嵌顯示、檔案提供下載連結

---

## 目錄結構

```
chat/
├── server/                 # ASP.NET Core 10 服務端
│   ├── ChatServer/         # 主 API + SignalR Hub（Controllers / Hubs / Services / Entities / Data）
│   ├── AdminServer/        # 後台管理 API
│   └── docker-compose.yml  # 一鍵拉起 PostgreSQL
├── client/
│   ├── flutter_chat/       # 用戶端（Flutter，已建置驗證）
│   └── flutter_admin/      # 管理端（Flutter，已建置驗證）
└── docs/
    ├── ARCHITECTURE.md     # 介面 / 協議契約（權威）
    └── HELP.md             # 客戶端使用幫助
```

---

## 1. 啟動服務端

### 前置
- .NET 10 SDK
- PostgreSQL（推薦用 docker 一鍵啟動）

### 啟動資料庫
```bash
cd server
docker compose up -d          # 啟動 PostgreSQL（埠號 5432，庫名/帳號/密碼見 docker-compose.yml）
```

### 配置（多環境）
配置依環境拆分，透過環境變數 `ASPNETCORE_ENVIRONMENT=Development|Production` 切換
（預設 Development）。詳見各服務下的：

- `appsettings.json` —— 公共基礎配置
- `appsettings.Development.json` —— 開發版（localhost、開發金鑰、寬鬆 CORS）
- `appsettings.Production.json` —— 正式版（**佔位值，部署前必須替換或用環境變數覆寫**：
  `CONNECTIONSTRINGS__DEFAULT`、`Jwt__Key`、`SeedAdmin__Password` 等）

常用配置鍵：`ConnectionStrings:Default`（PostgreSQL 連線字串）、`Jwt:Key`（簽章金鑰）、
`Urls`（監聽位址）、`Cors:Origins`（允許的前端來源）。

### 執行
```bash
cd server/ChatServer
dotnet run -c Release
# 或發佈
dotnet publish -c Release -o out
```
啟動後：
- API 基址：`http://localhost:5298`
- Swagger 文件：`http://localhost:5298/swagger`
- SignalR Hub：`http://localhost:5298/hubs/chat`
- 健康檢查：`http://localhost:5298/health`（回傳 `Healthy` 表示程序與資料庫均正常）
- 靜態檔案 / 上傳檔案：`http://localhost:5298/files/...`

> EF Core 在啟動時自動 `EnsureCreated()` 建表（示範用）。生產建議改用遷移
> `dotnet ef migrations add Init && dotnet ef database update`。

AdminServer 同理（`http://localhost:5299`，`/health` 同樣可用）。

---

## 2. Flutter 客戶端

原始碼位於 `client/flutter_chat`（用戶端）與 `client/flutter_admin`（管理端）。

### 本地開發
```bash
cd client/flutter_chat
flutter pub get
flutter run -d chrome      # 網頁端
flutter run -d android     # 安卓真機 / 模擬器
```

API 位址設定方式（擇一）：
- **建置期**：`flutter build web --dart-define=API_BASE=https://your.api`
- **執行期**：登入頁「設定」中手動覆寫，或用配置連結一鍵匯入（見 `docs/HELP.md`）

### 建置與發佈
客戶端建置、Android APK 拆分打包、iOS 建置與靜態站點發佈均由 CI 自動完成，詳見第 4 節。
客戶端功能（掃一掃、配置連結、下載頁等）見 [`docs/HELP.md`](docs/HELP.md)。

---

## 3. 介面與協議契約

REST 介面、SignalR Hub 協議、訊息結構等以 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) 為準。
關鍵端點速覽：

- 認證：`POST /api/auth/register`、`POST /api/auth/login`（回傳 `token` + `user`）
- 用戶 / 好友：`GET /api/users/search`、`POST /api/friends/request`、`GET /api/friends` 等
- 群組 / 會話：`POST /api/groups`、`GET /api/conversations`
- 檔案：`POST /api/files/upload`（multipart，欄位 `file`）
- 即時：`/hubs/chat`（`SendPrivateMessage` / `SendGroupMessage` / `JoinGroup`；推送 `ReceiveMessage` / `UserOnline` / `UserOffline`）

所有 REST 請求需在 Header 帶 `Authorization: Bearer <token>`。

---

## 4. CI/CD 與前端靜態發佈

`.github/workflows/ci-cd.yml` 在 push / PR 時跑品質門禁（.NET 建置 + Flutter analyze），
push 到 `main` 時額外建置兩個 Flutter Web 應用 **和 Android APK**，合併後一起發佈：

| 產物 | 發佈路徑 |
| --- | --- |
| `client/flutter_chat`（用戶端） | <https://servestatic.github.io/Chat/> |
| `client/flutter_admin`（管理端） | <https://servestatic.github.io/Chat/admin/> |
| Android APK 下載頁 | <https://servestatic.github.io/Chat/download/> |
| 配置連結產生器 | <https://servestatic.github.io/Chat/config/> |

站點託管在 [`ServeStatic/Chat`](https://github.com/ServeStatic/Chat) 倉庫的 `gh-pages` 分支。

### Android APK

每次部署依 **CPU 架構拆分**建置安裝包（universal 包因超 GitHub 單檔 100MB 限制已移除）：

| 檔案 | 說明 |
| --- | --- |
| `chat-arm64-v8a.apk` | 絕大多數現代手機，體積最小（推薦） |
| `chat-armeabi-v7a.apk` | 較舊的 32 位元裝置 |
| `chat-x86_64.apk` | 模擬器與部分平板 |

下載頁由 `.github/scripts/gen-download-page.sh` 產生，每個 APK 卡片內嵌其下載位址的 QR Code，
頁尾另提供「聊天應用」「配置產生器」的直達 QR Code。

#### 關於簽名

release 版使用 Flutter 範本預設的 debug key 簽名，因此 CI 無需 keystore，但：
1. 安裝時 Google Play 防護會提示「未知發佈者」，需選「仍要安裝」；
2. 更換簽名 key 會導致已裝用戶無法覆蓋升級，必須先解除安裝。

正式發佈前建議在 `build.gradle.kts` 定義 `signingConfigs.release`，把 keystore 用 base64
存入 secret（如 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEY_*`），在 `build-android` job 解碼後建置。

#### iOS 建置與 TestFlight 上傳

`build-ios` 在 `macos-latest` runner 上執行（Xcode 僅 macOS 提供）。預設產出**未簽名**的
`Runner.app`（僅編譯檢查）。

##### 已簽名 IPA（可安裝到裝置）

當配置以下 secrets 時自動產出**已簽名** `Runner.ipa`：

| Secret | 說明 |
| --- | --- |
| `IOS_DIST_CERT_BASE64` | 分發憑證 p12，base64 編碼 |
| `IOS_DIST_CERT_PASSWORD` | p12 密碼 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision`，base64 編碼（**TestFlight 須為 App Store Connect 類型**，非 Ad Hoc） |
| `IOS_TEAM_ID`（可選） | Apple Team ID |

未配置時自動回退未簽名建置，CI 不失敗。`ExportOptions.plist` 位於
`client/flutter_chat/ios/ExportOptions.plist`，其 `method` 已設為 `app-store`。

##### 上傳到 TestFlight

在已簽名下，再配置以下三項 App Store Connect API 金鑰，CI 會自動把 IPA 上傳到
App Store Connect（上傳後於 TestFlight 建群即可）：

| Secret | 說明 |
| --- | --- |
| `IOS_APP_STORE_CONNECT_API_KEY_BASE64` | `AuthKey_XXXX.p8`，base64 編碼 |
| `IOS_APP_STORE_CONNECT_KEY_ID` | API Key ID（10 碼，如 `ABCD123456`） |
| `IOS_APP_STORE_CONNECT_ISSUER_ID` | Issuer ID（UUID） |

**如何取得 App Store Connect API 金鑰：**
1. 登入 [App Store Connect](https://appstoreconnect.apple.com) → 使用者與存取 → **整合** → App Store Connect API → 「+」新建（金鑰在「整合」標籤下，不在「使用者」標籤）。
2. 選 **團隊金鑰**（非個人金鑰）。
3. 權限選 **App 管理**（App Manager）；僅「開發者」權限無法上傳 IPA。
4. 頁面頂部 **Issuer ID**（UUID）即 `IOS_APP_STORE_CONNECT_ISSUER_ID`；新建後顯示的 **Key ID** 即 `IOS_APP_STORE_CONNECT_KEY_ID`。
5. 點「下載 API 金鑰」取得 `AuthKey_XXXX.p8`（**僅可下載一次**，請本地備份），base64 編碼後填入 `IOS_APP_STORE_CONNECT_API_KEY_BASE64`：
   - macOS/Linux：`base64 -w0 AuthKey_XXXX.p8`
   - Windows PowerShell：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8"))`

### 一次性配置

> `gh-pages` 分支首次部署時由 workflow 自動建立（force push），無需手動建；但 Pages 設定
> 只列已存在分支，故「開啟 Pages」須排在首次部署之後。

1. **部署令牌**：產生對 `ServeStatic/Chat` 有寫權限（`repo` scope）的 PAT，在本倉庫
   **Settings → Secrets and variables → Actions** 新增為 `SERVESTATIC_DEPLOY_TOKEN`。
2. **（可選）線上 API 位址**：在 **Settings → Secrets and variables → Actions → Variables** 新增
   - `PUBLIC_API_BASE` —— 用戶端 API 基址（`--dart-define=API_BASE`）
   - `PUBLIC_ADMIN_API_BASE` —— 管理端 API 基址（`--dart-define=ADMIN_API_BASE`）
   - `PUBLIC_WEB_BASE` —— 靜態站點根位址，預設 `https://servestatic.github.io/Chat/`，
     影響下載頁 QR Code 指向（自訂網域時設定）

   未設定則發佈版仍連 `http://localhost:5298 / :5299`；用戶也可在「設定」中手動覆寫。
3. **（可選）下載頁位址**：若靜態站點與 API 不同域，建置時注入
   `DOWNLOAD_URL`（`--dart-define=DOWNLOAD_URL=https://example.com/download/`），
   登入頁「下載客戶端」按鈕會隨之變化；亦可用配置連結在執行期下發（見 `docs/HELP.md`）。
4. **觸發首次部署**：push 到 `main`，等 `Deploy to ServeStatic/Chat` job 完成（此時才出現 `gh-pages` 分支）。
5. **開啟 Pages**：在 `ServeStatic/Chat` 的 **Settings → Pages** 選擇
   *Build and deployment → Source: Deploy from a branch*，分支 `gh-pages`、目錄 `/ (root)`。

> 專案頁 URL 大小寫敏感，`--base-href` 使用 `/Chat/`、`/Chat/admin/`；自訂域或組織首頁需改為 `/`、`/admin/`。

### 客戶端功能

- **掃一掃**：登入頁與「發現」頁入口，可辨識網頁連結、配置連結（`fairchat://config`）、純文字。
- **下載頁**：<https://servestatic.github.io/Chat/download/>，各架構 APK 帶 QR Code。
- **配置連結產生器**：<https://servestatic.github.io/Chat/config/>，視覺化產生 `fairchat://config` 連結。

---

## 5. 已知邊界與後續擴充

- **持久化**：PostgreSQL + EF Core，未做訊息分頁游標 / 已讀回執落庫（協議已預留 `ReadReceipt`）。
- **水平擴充**：SignalR 單機記憶體 `PresenceTracker`；多實例需 Redis Backplane + 外部 ID 分發。
- **安全**：JWT 金鑰與 CORS 為示範配置，生產請用強金鑰、HTTPS、嚴格 CORS、檔案校驗與病毒掃描。
- **推送**：原生端生產建議接入 FCM / APNs 做離線推送（SignalR 僅線上即時通道）。
