#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_ROOT/app"
TARGET="${1:-auto}"

if [ "$TARGET" = "auto" ]; then
  case "$(uname -s)" in
    Darwin)
      TARGET="macos"
      ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT)
      TARGET="windows"
      ;;
    *)
      echo "エラー: 未対応のOSです。引数に 'macos' または 'windows' を指定してください。"
      exit 1
      ;;
  esac
fi

if [ "$TARGET" != "macos" ] && [ "$TARGET" != "windows" ]; then
  echo "エラー: 対象プラットフォームは 'macos' または 'windows' のみ指定できます。"
  exit 1
fi

if command -v fvm >/dev/null 2>&1; then
  FLUTTER_CMD=(fvm flutter)
else
  FLUTTER_CMD=(flutter)
fi

echo "=== Blink: Flutter ${TARGET} ビルド ==="

# Rust ライブラリビルド（リリース）
echo "[1/4] Rust ライブラリビルド..."
cargo build --manifest-path "$PROJECT_ROOT/core/Cargo.toml" -p core_api --release

# Flutter 依存取得
echo "[2/4] Flutter 依存取得..."
cd "$APP_DIR"
"${FLUTTER_CMD[@]}" pub get

if [ "$TARGET" = "macos" ]; then
  # Flutter macOS リリースビルド
  echo "[3/4] Flutter macOS ビルド..."
  "${FLUTTER_CMD[@]}" build macos --release

  # ZIP アーカイブ作成
  echo "[4/4] ZIP アーカイブ作成..."
  BUILD_DIR="$APP_DIR/build/macos/Build/Products/Release"
  cd "$BUILD_DIR"

  # Ad-hoc コード署名（個人配布用）
  codesign --force --deep --sign - Blink.app 2>/dev/null || true

  # ZIP 作成
  zip -r "$PROJECT_ROOT/Blink-macos.zip" Blink.app
else
  # Flutter Windows リリースビルド
  echo "[3/4] Flutter Windows ビルド..."
  "${FLUTTER_CMD[@]}" build windows --release

  echo "[4/4] Windows アーカイブ作成..."
  BUILD_DIR="$APP_DIR/build/windows/x64/runner/Release"
  cd "$BUILD_DIR"
  if command -v zip >/dev/null 2>&1; then
    zip -r "$PROJECT_ROOT/Blink-windows.zip" .
  else
    echo "警告: zip コマンドが見つからないためアーカイブをスキップします。"
    echo "成果物ディレクトリ: $BUILD_DIR"
  fi
fi

echo ""
echo "=== ビルド完了 ==="
if [ "$TARGET" = "macos" ]; then
  echo "出力: $PROJECT_ROOT/Blink-macos.zip"
else
  echo "出力: $PROJECT_ROOT/Blink-windows.zip"
fi
