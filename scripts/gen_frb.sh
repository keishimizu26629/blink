#!/usr/bin/env bash
set -euo pipefail

# flutter_rust_bridge コード生成
# Flutter プロジェクト（app/）のセットアップ後に実行する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Blink: flutter_rust_bridge コード生成 ==="

flutter_rust_bridge_codegen generate \
  --rust-input "$PROJECT_ROOT/core/crates/core_api/src/lib.rs" \
  --dart-output "$PROJECT_ROOT/app/lib/src/bridge/generated/"
