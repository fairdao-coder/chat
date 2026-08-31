# 客户端使用帮助（Flutter 用户端）

本文档面向**最终用户与部署者**，介绍用户端（`client/flutter_chat`）的几个便捷功能：
下载页、扫一扫、配置链接、登录页「下载客户端」入口。

> 部署地址（示例，实际以你的部署为准）：
> - 聊天应用：<https://servestatic.github.io/Chat/>
> - 下载页：<https://servestatic.github.io/Chat/download/>
> - 配置链接生成器：<https://servestatic.github.io/Chat/config/>

---

## 1. 下载页

访问下载页即可获取 Android 安装包。每次发布按 **CPU 架构拆分**提供安装包：

| 文件 | 适合设备 |
| --- | --- |
| `chat-arm64-v8a.apk` | 绝大多数现代手机（推荐，体积最小） |
| `chat-armeabi-v7a.apk` | 较旧的 32 位设备 |
| `chat-x86_64.apk` | 模拟器 / 部分平板 |

**每个安装包卡片都带二维码**：用手机相机或扫码 App 扫一下即可直接下载安装。
页尾还提供「聊天应用」「配置生成器」两个页面的直达二维码。

安装提示（Android 默认拦截非商店安装包）：
1. 下载后打开 APK，系统提示「未知来源」时，按提示允许「允许来自此来源」。
2. 当前构建使用 `debug` 签名，Google Play 防护会显示警示，选择「仍要安装」即可。
3. 若换过签名 key，需先卸载旧版再装新版（否则无法覆盖升级）。

---

## 2. 扫一扫

在 **登录页**和「**发现**」页都有「扫一扫」入口。支持三类内容：

| 扫描内容 | 行为 |
| --- | --- |
| 普通网页链接（`http(s)://...`） | 直接打开网页 |
| 配置链接（`fairchat://config?...`） | 一键导入服务器地址、品牌名、Logo、下载页等（见第 3 节） |
| 纯文本 | 弹窗显示文本 |

> 摄像头权限：App 首次扫码会请求相机权限；Web 端需在 HTTPS 或 localhost 下才能使用摄像头。

---

## 3. 配置链接

配置链接是一种 `fairchat://config` 开头的深链，可一次性把客户端指向你的服务器并定制外观。
最方便的做法是用 **配置链接生成器**（见上「部署地址」中的 `/config/` 页面）：

1. 打开配置生成器，填写：
   - **API 地址**：你的服务端地址（如 `https://chat.example.com`）
   - **品牌名**（可选）：登录页等位置显示的应用名
   - **Logo 图片 URL**（可选，`http(s)://`）：应用内 Logo
   - **下载页地址**（可选）：登录页「下载客户端」按钮指向的页面
2. 复制生成的 `fairchat://config?...` 链接，或下载其二维码。
3. 在客户端「扫一扫」中扫描该链接 / 二维码，按提示确认即可生效。

完整参数（`fairchat://config` 的 query 部分）：

| 参数 | 说明 | 约束 |
| --- | --- | --- |
| `api` | 服务器地址 | 非空即生效；设置后登录页隐藏地址输入框 |
| `name` | 品牌名 | 非空即生效 |
| `logo` | 应用内 Logo 图片 URL | `http(s)://` 设置；留空 = 恢复内置默认；缺省 = 不变 |
| `download` | 下载页地址 | 必须是 `http(s)://` 绝对地址 |

配置会保存在本机（SharedPreferences），下次打开自动沿用。

---

## 4. 登录页「下载客户端」

登录页在「扫一扫导入配置」下方提供「下载客户端」按钮，点击会在外部浏览器打开
**下载页**（第 1 节）。该按钮指向的地址由 `AppConfig.downloadUrl` 决定：

- **默认值**：`https://servestatic.github.io/Chat/download/`
- **构建时覆盖**：`flutter build web --dart-define=DOWNLOAD_URL=https://example.com/download/`
- **运行时覆盖**：通过配置链接的 `download` 参数下发（第 3 节）

---

## 5. 常见问题（FAQ）

**Q：扫码没反应 / 打不开相机？**
- App 端：检查是否已授予相机权限。
- Web 端：摄像头仅在 HTTPS 或 `localhost` 下可用，HTTP 内网地址无法调用相机（可改用复制链接方式）。

**Q：下载页二维码扫了之后下不动？**
- 下载页为静态托管（GitHub Pages 等），扫码后手机浏览器直接下载 APK。
- 若你的网络无法访问该静态站点，请改用电脑打开下载页手动传输 APK。

**Q：配置链接设置错了怎么办？**
- 在登录页「设置」中可手动改回 API 地址；或重新扫一个正确的配置链接覆盖。
- `logo` 参数留空可恢复内置默认 Logo。

**Q：iOS 有安装包吗？**
- 下载页目前仅提供 Android APK。iOS 需由部署方配置 Apple 开发者证书后在 CI 产出已签名 IPA，
  或自行用 Mac 对未签名构建重新签名。详见主仓库 `README.md` 第 5 节「iOS 构建（可选签名）」。

---

## 6. 检测后台服务是否正常

两个服务端（ChatServer、AdminServer）都暴露了健康检查端点 `/health`，
它会在内部执行一次数据库连接检查，因此能同时反映「进程存活」与「数据库可达」。

部署地址示例：

| 服务 | 健康检查地址 |
| --- | --- |
| ChatServer | `https://<chat-host>/health` |
| AdminServer | `https://<admin-host>/health` |

### 命令行检测

```bash
# 返回 HTTP 200 + {"status":"Healthy"} 表示正常
curl -f -s https://<chat-host>/health || echo "ChatServer 异常"

# 仅看 HTTP 状态码
curl -o /dev/null -w "%{http_code}\n" https://<admin-host>/health
```

- 状态码 `200` + `status: Healthy` → 服务与数据库均正常。
- 状态码 `503` 或 `Unhealthy` → 进程在但数据库连不上（检查连接串、Postgres 是否启动）。
- 连接超时 / 拒绝 → 进程未启动或端口/防火墙问题。

### 在客户端 / 监控中检测

- **前端轮询**：聊天端可在启动时 `fetch('/health')`，非 `Healthy` 时提示「服务暂不可用」。
- **负载均衡 / 容器编排**：把 `/health` 配为 liveness / readiness 探针（K8s、Docker Swarm、Nginx upstream 健康检查等）。
- **CI / 运维脚本**：部署后 `curl -f` 校验，失败则告警或回滚。

> 注意：`/health` 不要求鉴权（匿名可访问），不会泄露业务数据，只返回聚合健康状态。

