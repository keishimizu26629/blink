#!/usr/bin/env bash
set -euo pipefail

# UniFFI で Swift bindings を生成するスクリプト
# ビルド端末（Xcode搭載Mac）で実行する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PROJECT_ROOT/core"
OUTPUT_DIR="$PROJECT_ROOT/mac-ui/Generated"
UDL_FILE="$CORE_DIR/crates/core_api/src/core_api.udl"

echo "=== Blink: UniFFI Swift Bindings 生成 ==="
echo "プロジェクトルート: $PROJECT_ROOT"

# 出力ディレクトリ作成
mkdir -p "$OUTPUT_DIR"

# UDL ファイルの存在チェック
if [ ! -f "$UDL_FILE" ]; then
    echo "エラー: UDL ファイルが見つかりません: $UDL_FILE"
    echo "Phase 1 後半で core_api.udl を作成してから再実行してください"
    exit 1
fi

# uniffi-bindgen で Swift バインディング生成
echo "--- uniffi-bindgen generate ---"
cargo run --manifest-path "$CORE_DIR/Cargo.toml" \
    -p uniffi-bindgen -- \
    generate "$UDL_FILE" \
    --language swift \
    --out-dir "$OUTPUT_DIR"

echo "=== 完了: $OUTPUT_DIR ==="
ls -la "$OUTPUT_DIR"
