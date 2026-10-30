#!/bin/zsh
# Mopad 构建脚本
#   ./Scripts/build.sh            仅构建到 build/Mopad.app
#   ./Scripts/build.sh install    构建并安装到 /Applications，然后启动
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD="$ROOT/build"
APP="$BUILD/Mopad.app"
BUNDLE_ID="com.zeki.mopad"

echo "▸ 编译…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc \
  -O -swift-version 5 \
  -target "$(uname -m)-apple-macos14.0" \
  -import-objc-header "$ROOT/Sources/Bridge.h" \
  -framework AppKit -framework SwiftUI -framework IOKit \
  -framework ApplicationServices -framework ServiceManagement \
  "$ROOT"/Sources/*.swift \
  -o "$APP/Contents/MacOS/Mopad"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
[[ -f "$ROOT/Resources/AppIcon.icns" ]] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"

echo "▸ 签名…"
# 优先使用本地自签名证书：签名指纹稳定，辅助功能授权在重新构建后仍然有效
IDENTITY="Mopad Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
  echo "  使用证书：$IDENTITY"
else
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
  echo "  ⚠ 未找到「$IDENTITY」，使用临时签名（每次重装需重新授权）"
fi

echo "✓ 构建完成：$APP"

if [[ "${1:-}" == "install" ]]; then
  echo "▸ 安装到 /Applications…"
  OLD_REQ=$( (codesign -dr - /Applications/Mopad.app 2>/dev/null || true) | grep designated || true)
  NEW_REQ=$( (codesign -dr - "$APP" 2>/dev/null || true) | grep designated || true)
  pkill -x Mopad 2>/dev/null || true
  sleep 0.5
  # 先完整复制到临时目录，再整包移入 /Applications，避免逐文件写入被系统「App 管理」保护拦截导致包残缺
  STAGE=$(mktemp -d)
  ditto "$APP" "$STAGE/Mopad.app"
  rm -rf /Applications/Mopad.app
  mv "$STAGE/Mopad.app" /Applications/Mopad.app
  rmdir "$STAGE"
  codesign --verify --strict /Applications/Mopad.app || { echo "✗ 安装后的应用签名校验失败"; exit 1; }
  if [[ -n "$OLD_REQ" && "$OLD_REQ" != "$NEW_REQ" ]]; then
    # 签名指纹变化，旧授权已失效，清掉以免出现「开关是开的但不生效」
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "  签名指纹已变化，请重新授予一次辅助功能权限"
  else
    echo "  签名指纹未变，沿用已有授权"
  fi
  open /Applications/Mopad.app
  echo "✓ 已启动"
fi
