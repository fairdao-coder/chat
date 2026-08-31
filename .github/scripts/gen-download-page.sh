#!/usr/bin/env bash
# 生成 Android APK 下載頁。
#
# 用法:
#   gen-download-page.sh <download-dir> <version> <short-sha>
#
# 在 <download-dir> 下產出 index.html，只列出目錄中「確實存在」的 APK，
# 避免產出指向不存在檔案的 404 下載連結。
#
# 注意: 本腳本必須以 LF 行尾執行。CI 中會先做 CR 清理再呼叫它。
set -euo pipefail

dir="${1:?usage: gen-download-page.sh <download-dir> <version> <short-sha>}"
version="${2:?missing version}"
sha="${3:?missing short sha}"

cd "$dir"

shopt -s nullglob
apks=( *.apk )
if [ "${#apks[@]}" -eq 0 ]; then
  echo "::error title=No APK produced::No .apk files found in $dir. The Android build produced nothing."
  exit 1
fi

human_size() {
  numfmt --to=iec --suffix=B --format='%.1f' "$(stat -c%s "$1")"
}

# card <file> <title> <desc> [primary]
# 檔案不存在時靜默跳過，不產生壞連結。
card() {
  local file="$1" title="$2" desc="$3" primary="${4:-no}"
  [ -f "$file" ] || return 0
  local size cls=""
  size="$(human_size "$file")"
  [ "$primary" = "yes" ] && cls=" card--primary"
  cat <<HTML
        <a class="card${cls}" href="${file}" download>
          <span class="card__text">
            <span class="card__title">${title}</span>
            <span class="card__desc">${desc}</span>
          </span>
          <span class="card__size">${size}</span>
          <span class="card__go" aria-hidden="true">&darr;</span>
        </a>
HTML
}

built="$(date -u '+%Y-%m-%d %H:%M UTC')"

{
  cat <<HEAD
<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>聊天 App 下載</title>
<meta name="description" content="聊天 App Android 安裝包下載">
<style>
  :root {
    --bg: #f6f7fb; --card: #ffffff; --text: #14161a; --muted: #6b7280;
    --accent: #2563eb; --accent-soft: #eff6ff; --border: #e5e7eb;
    --shadow: 0 1px 2px rgba(16,24,40,.06), 0 8px 24px rgba(16,24,40,.06);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0f1116; --card: #171a21; --text: #e8eaed; --muted: #9aa3b2;
      --accent: #60a5fa; --accent-soft: #14243d; --border: #262b36;
      --shadow: 0 1px 2px rgba(0,0,0,.4), 0 8px 24px rgba(0,0,0,.35);
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 48px 20px 64px;
    background: var(--bg); color: var(--text);
    font-family: system-ui, -apple-system, "Segoe UI", "Noto Sans TC",
                 "Microsoft JhengHei", sans-serif;
    line-height: 1.6;
  }
  .wrap { max-width: 720px; margin: 0 auto; }
  header { margin-bottom: 28px; }
  h1 { margin: 0 0 8px; font-size: 28px; letter-spacing: -.02em; }
  .sub { margin: 0; color: var(--muted); font-size: 15px; }
  .list { display: grid; gap: 12px; margin: 0 0 24px; }
  .card {
    display: flex; align-items: center; gap: 16px;
    padding: 16px 18px; border: 1px solid var(--border); border-radius: 14px;
    background: var(--card); box-shadow: var(--shadow);
    color: inherit; text-decoration: none;
    transition: transform .12s ease, border-color .12s ease;
  }
  .card:hover { transform: translateY(-2px); border-color: var(--accent); }
  .card--primary { border-color: var(--accent); background: var(--accent-soft); }
  .card__text { flex: 1; min-width: 0; display: flex; flex-direction: column; }
  .card__title { font-weight: 600; font-size: 16px; }
  .card__desc { color: var(--muted); font-size: 13.5px; }
  .card__size {
    font-variant-numeric: tabular-nums; font-size: 13px; color: var(--muted);
    white-space: nowrap;
  }
  .card__go {
    width: 32px; height: 32px; flex: none; border-radius: 50%;
    display: grid; place-items: center;
    background: var(--accent); color: #fff; font-size: 16px;
  }
  .note {
    padding: 14px 16px; border-radius: 12px; font-size: 13.5px;
    background: var(--card); border: 1px solid var(--border); color: var(--muted);
  }
  .note strong { color: var(--text); }
  footer {
    margin-top: 20px; font-size: 12.5px; color: var(--muted);
    display: flex; flex-wrap: wrap; gap: 6px 18px;
  }
  footer a { color: var(--accent); text-decoration: none; }
  footer a:hover { text-decoration: underline; }
  code {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 12.5px;
  }
</style>
</head>
<body>
  <div class="wrap">
    <header>
      <h1>聊天 App 下載</h1>
      <p class="sub">選擇適合你設備的 Android 安裝包。</p>
    </header>

    <div class="list">
HEAD

  card chat-arm64-v8a.apk   "arm64-v8a · 推薦"    "絕大多數現代 Android 手機，體積最小" yes
  card chat-universal.apk   "通用版 · 相容性最好" "包含所有 CPU 架構，任何設備都能安裝，體積較大"
  card chat-armeabi-v7a.apk "armeabi-v7a"         "較舊的 32 位元設備"
  card chat-x86_64.apk      "x86_64"              "模擬器與部分平板"

  cat <<FOOT
    </div>

    <div class="note">
      <strong>安裝提示</strong><br>
      Android 預設封鎖非官方商店的安裝包，安裝時請在系統設定中允許
      「未知來源 / 允許來自此來源的應用程式」。<br>
      目前版本使用 <code>debug</code> 簽章建置，Google Play 防護可能會顯示警示，
      選擇「仍要安裝」即可。
    </div>

    <footer>
      <span>版本 <code>${version}</code></span>
      <span>建置時間 <code>${built}</code></span>
      <span>Commit <code>${sha}</code></span>
      <span><a href="../">返回聊天應用</a></span>
      <span><a href="../config/">設定連結產生器</a></span>
    </footer>
  </div>
</body>
</html>
FOOT
} > index.html

echo "generated $(pwd)/index.html with ${#apks[@]} apk(s): ${apks[*]}"
