import 'dart:convert';

/// 小程式默認模板：欄目**未配置內容**（content 為空）時展示。
///
/// 面向管理員 / 開發者，展示當前登錄用戶、Token 與 Bridge 調用示例，
/// 便於在接入真實業務前驗證宿主能力聯通性。
///
/// 客戶端渲染約束（與 `script:` 內聯 HTML 一致，違反會被**靜默剔除**）：
/// 1. 內聯 HTML 是**片段**，不可寫 `<html>` / `<head>` / `<body>`；
/// 2. Web 端校驗器**不允許 `<style>` 元素**，一律用 `style="..."` 行內樣式；
/// 3. 事件綁定一律用 `addEventListener`（`onclick` 僅對表單類元素放行）；
/// 4. 深色模式由腳本監聽 `prefers-color-scheme` 後改寫行內樣式。
String buildDefaultMiniAppHtml({
  required String? columnTitle,
  required String? userId,
  required String? nickName,
  required String? userName,
  required String? token,
}) {
  final title =
      columnTitle?.trim().isNotEmpty == true ? columnTitle!.trim() : '小程式';
  final uid = (userId ?? '').trim();
  final atName = (userName ?? '').trim();
  final name = nickName?.trim().isNotEmpty == true ? nickName!.trim() : atName;
  final displayName = name.isEmpty ? '未登錄' : name;
  final rawToken = token ?? '';
  final tokenPreview = rawToken.isEmpty
      ? '（未取得 Token）'
      : (rawToken.length > 28 ? '${rawToken.substring(0, 28)}…' : rawToken);

  // 行內樣式常量（不能用 <style>，見上方約束 2）。
  const card =
      'margin-top:14px;padding:16px;background:#fff;border-radius:14px;'
      'box-shadow:0 4px 18px rgba(0,0,0,.06)';
  const label = 'font-size:13px;font-weight:600';
  const sub = 'font-size:12px;color:#8a8f98';
  const btn =
      'padding:8px 14px;font-size:13px;border:0;border-radius:10px;'
      'cursor:pointer;background:#1aad19;color:#fff';
  const ghost =
      'padding:8px 14px;font-size:13px;border:1px solid #d7d9de;'
      'border-radius:10px;cursor:pointer;background:transparent;color:inherit';
  const input =
      'flex:1;min-width:140px;padding:8px 10px;font-size:13px;'
      'border:1px solid #d7d9de;border-radius:10px;background:transparent;'
      'color:inherit';

  return '''
<div id="mini-app" style="font-family:system-ui,-apple-system,'Segoe UI',sans-serif;padding:18px;min-height:100%;box-sizing:border-box;background:#f7f8fa;color:#1b1c1e">
  <div style="max-width:640px;margin:0 auto">
    <div class="mini-card" style="padding:20px 14px;text-align:center;background:#fff;border-radius:16px;box-shadow:0 4px 18px rgba(0,0,0,.06)">
      <div style="font-size:44px;line-height:1">🧩</div>
      <div style="margin-top:10px;font-size:20px;font-weight:600">${_esc(title)}</div>
      <div style="margin-top:6px;$sub">尚未配置內容，當前展示默認模板</div>
    </div>

    <div class="mini-card" style="$card">
      <div style="$label">👤 當前用戶</div>
      <div id="mini-user" style="margin-top:8px;font-size:15px">${_esc(displayName)}${atName.isNotEmpty ? '（@${_esc(atName)}）' : ''}</div>
      <div style="margin-top:4px;$sub">ID：${uid.isEmpty ? '（無）' : _esc(uid)}</div>
    </div>

    <div class="mini-card" style="$card">
      <div style="$label">🔑 Token</div>
      <div id="mini-token" style="margin-top:8px;font-size:11px;font-family:ui-monospace,Menlo,Consolas,monospace;word-break:break-all;$sub">${_esc(tokenPreview)}</div>
      <div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap">
        <button id="mini-copy" style="$ghost">複製</button>
        <button id="mini-token-btn" style="$ghost">透過 Bridge 取得</button>
      </div>
    </div>

    <div class="mini-card" style="$card">
      <div style="$label">🧩 Bridge 調用示例</div>
      <div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap">
        <button id="mini-toast" style="$btn">ui.toast</button>
        <button id="mini-user-btn" style="$btn">auth.user</button>
        <button id="mini-open" style="$ghost">ui.open</button>
      </div>
      <div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap">
        <input id="mini-to" type="text" placeholder="對方 ID" value="${_esc(uid)}" style="$input" />
        <button id="mini-send" style="$ghost">chat.send</button>
      </div>
      <div id="mini-out" style="margin-top:12px;$sub">等待操作…</div>
    </div>
  </div>
</div>
<script>
(function () {
  var root = document.getElementById('mini-app');
  var out = document.getElementById('mini-out');
  var tokenView = document.getElementById('mini-token');
  var userInfo = document.getElementById('mini-user');

  var TITLE = ${_js(title)};
  var INIT_TOKEN = ${_js(rawToken)};
  var INIT_USER = { id: ${_js(uid)}, nickName: ${_js(name)}, userName: ${_js(atName)} };

  function setOut(text, isErr) {
    out.textContent = text;
    out.style.color = isErr ? '#e04b4b' : '#1aad19';
  }

  // 所有 Bridge 按鈕的統一前置校驗：容器內才有 window.ChatBridge。
  function require(fn) {
    return function () {
      var b = window.ChatBridge && window.ChatBridge.call ? window.ChatBridge : null;
      if (!b) { setOut('ChatBridge 不可用：請在 App 內以 script: 類型打開', true); return; }
      fn(b);
    };
  }

  function errText(e) { return e && e.message ? e.message : String(e); }

  function renderUser(u) {
    if (!u) { userInfo.textContent = '未登錄'; return ''; }
    var n = u.nickName || u.userName || '未命名';
    userInfo.textContent = n + (u.userName ? '（@' + u.userName + '）' : '');
    return u.id || '';
  }

  renderUser(INIT_USER);

  // 深色模式：不能用 <style>，改由腳本改寫行內樣式。
  function applyTheme() {
    var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    root.style.background = dark ? '#17181a' : '#f7f8fa';
    root.style.color = dark ? '#eceef1' : '#1b1c1e';
    var cards = root.querySelectorAll('.mini-card');
    for (var i = 0; i < cards.length; i++) {
      cards[i].style.background = dark ? '#222427' : '#ffffff';
    }
  }
  applyTheme();
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    if (mq.addEventListener) { mq.addEventListener('change', applyTheme); }
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    try {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
    } catch (e) {}
    return Promise.resolve();
  }

  function showToken(t) {
    tokenView.textContent = t ? (t.length > 28 ? t.slice(0, 28) + '…' : t) : '（未取得 Token）';
  }

  document.getElementById('mini-copy').addEventListener('click', function () {
    copyText(INIT_TOKEN).then(function () {
      setOut('Token 已複製（長度 ' + INIT_TOKEN.length + '）');
    });
  });

  document.getElementById('mini-token-btn').addEventListener('click', require(function (b) {
    b.call('auth.token').then(function (t) {
      INIT_TOKEN = t || '';
      showToken(INIT_TOKEN);
      setOut('auth.token 成功（長度 ' + INIT_TOKEN.length + '）');
    }).catch(function (e) { setOut('auth.token 失敗：' + errText(e), true); });
  }));

  document.getElementById('mini-toast').addEventListener('click', require(function (b) {
    b.call('ui.toast', { message: '來自 ' + TITLE + ' 的 Bridge 測試' })
      .then(function () { setOut('ui.toast 呼叫成功'); })
      .catch(function (e) { setOut('ui.toast 失敗：' + errText(e), true); });
  }));

  document.getElementById('mini-user-btn').addEventListener('click', require(function (b) {
    b.call('auth.user').then(function (u) {
      renderUser(u);
      setOut('auth.user 成功：' + (u ? (u.nickName || u.userName) : '未登錄'));
    }).catch(function (e) { setOut('auth.user 失敗：' + errText(e), true); });
  }));

  document.getElementById('mini-open').addEventListener('click', require(function (b) {
    b.call('ui.open', { url: 'https://flutter.dev' })
      .then(function () { setOut('ui.open 呼叫成功'); })
      .catch(function (e) { setOut('ui.open 失敗：' + errText(e), true); });
  }));

  document.getElementById('mini-send').addEventListener('click', require(function (b) {
    var to = document.getElementById('mini-to').value;
    if (!to) { setOut('請填寫對方 ID', true); return; }
    b.call('chat.send', { to: to, text: '來自 ' + TITLE + ' 的測試消息', isGroup: false })
      .then(function () { setOut('chat.send 成功'); })
      .catch(function (e) { setOut('chat.send 失敗：' + errText(e), true); });
  }));
})();
</script>
''';
}

/// HTML 文本轉義（用於元素內容與屬性值）。
String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// 生成安全的 JS 字符串字面量（自帶引號）。
///
/// 額外轉義 `</` 與 `<!--`，避免內容提前閉合 `<script>` 破壞整個片段。
/// JS 中 `"\/"` 等價於 `"/"`，故轉義後語義不變。
String _js(String s) => jsonEncode(s)
    .replaceAll('</', r'<\/')
    .replaceAll('<!--', r'<\!--');
