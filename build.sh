#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_INSTALL_DIR="${APP_INSTALL_DIR:-$HOME/Applications/CatKeyLock.app}"
CONTENTS_DIR="$APP_INSTALL_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
TEST_BIN="$BUILD_DIR/CatKeyLockTests"
ARCH="$(uname -m)"
TARGET="${TARGET:-${ARCH}-apple-macosx14.0}"

mkdir -p "$BUILD_DIR"

echo "==> [1/5] 编译并运行单元测试..."
swiftc -swift-version 5 -O -target "$TARGET" \
    "$ROOT_DIR/Sources/KeyCombo.swift" \
    "$ROOT_DIR/Sources/KeyboardLockEngine.swift" \
    "$ROOT_DIR/Tests/RunTests.swift" \
    -o "$TEST_BIN"
"$TEST_BIN"

echo "==> [2/5] 生成应用图标 (AppIcon.icns)..."
rm -rf "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/generate_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/AppIcon.icns"

echo "==> [3/5] 编译 CatKeyLock 主程序..."
swiftc -swift-version 5 -O -target "$TARGET" \
    "$ROOT_DIR/Sources/"*.swift \
    -framework AppKit \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -framework ServiceManagement \
    -framework SwiftUI \
    -o "$BUILD_DIR/CatKeyLock"

echo "==> [4/5] 组装 .app 包至 $APP_INSTALL_DIR ..."
if [[ "${SKIP_TCC_RESET:-0}" != "1" ]]; then
    pkill -x CatKeyLock || true
    sleep 0.3
fi
mkdir -p "$(dirname "$APP_INSTALL_DIR")"
rm -rf "$APP_INSTALL_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/CatKeyLock" "$MACOS_DIR/CatKeyLock"
chmod +x "$MACOS_DIR/CatKeyLock"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

echo "==> [5/5] 执行固定标识符签名并清理旧授权缓存..."
codesign --force --deep --sign - --identifier com.jianhe.CatKeyLock "$APP_INSTALL_DIR"
codesign -dv --verbose=2 "$APP_INSTALL_DIR" 2>&1 | grep -E "Identifier=|Format=|Signature="
if [[ "${SKIP_TCC_RESET:-0}" != "1" ]]; then
    /usr/bin/tccutil reset Accessibility com.jianhe.CatKeyLock || true
fi

echo "✅ 构建完成: $APP_INSTALL_DIR"
