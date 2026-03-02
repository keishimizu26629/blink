#!/usr/bin/env bash
set -euo pipefail

# flutter_rust_bridge コード生成
# Flutter プロジェクト（app/）のセットアップ後に実行する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_ROOT/app"

if ! command -v fvm >/dev/null 2>&1; then
  echo "エラー: fvm が見つかりません。先に fvm をインストールしてください。"
  exit 1
fi

echo "=== Blink: flutter_rust_bridge コード生成 (fvm) ==="
cd "$APP_DIR"

fvm flutter pub get

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "エラー: flutter_rust_bridge_codegen が見つかりません。"
  echo "実行例: cargo install flutter_rust_bridge_codegen"
  exit 1
fi

flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
