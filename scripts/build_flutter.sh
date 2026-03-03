#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_ROOT/app"

echo "=== Blink: Flutter macOS ビルド ==="

# Rust ライブラリビルド（リリース）
echo "[1/4] Rust ライブラリビルド..."
cargo build --manifest-path "$PROJECT_ROOT/core/Cargo.toml" --release

# Flutter 依存取得
echo "[2/4] Flutter 依存取得..."
cd "$APP_DIR"
flutter pub get

# Flutter macOS リリースビルド
echo "[3/4] Flutter macOS ビルド..."
flutter build macos --release

# ZIP アーカイブ作成
echo "[4/4] ZIP アーカイブ作成..."
BUILD_DIR="$APP_DIR/build/macos/Build/Products/Release"
cd "$BUILD_DIR"

# Ad-hoc コード署名（個人配布用）
codesign --force --deep --sign - Blink.app 2>/dev/null || true

# ZIP 作成
zip -r "$PROJECT_ROOT/Blink-macos.zip" Blink.app

echo ""
echo "=== ビルド完了 ==="
echo "出力: $PROJECT_ROOT/Blink-macos.zip"
