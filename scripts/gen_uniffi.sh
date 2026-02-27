#!/usr/bin/env bash
set -euo pipefail

# UniFFI (proc-macro mode) で Swift bindings を生成するスクリプト
# ビルド端末（Xcode搭載Mac）で実行する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PROJECT_ROOT/core"
OUTPUT_DIR="$PROJECT_ROOT/mac-ui/Generated"

echo "=== Blink: UniFFI Swift Bindings 生成 (proc-macro mode) ==="
echo "プロジェクトルート: $PROJECT_ROOT"

# 出力ディレクトリ作成
mkdir -p "$OUTPUT_DIR"

# まず cdylib をビルド（UniFFI メタデータを含む .dylib を生成）
echo "--- cargo build (cdylib) ---"
(
    cd "$CORE_DIR"
    cargo build -p core_api
)

# dylib のパスを特定
DYLIB_PATH="$CORE_DIR/target/debug/libcore_api.dylib"
if [ ! -f "$DYLIB_PATH" ]; then
    echo "エラー: dylib が見つかりません: $DYLIB_PATH"
    echo "cargo build が成功しているか確認してください"
    exit 1
fi

# uniffi-bindgen で Swift バインディング生成
echo "--- uniffi-bindgen generate --library ---"
(
    cd "$CORE_DIR"
    cargo run -p uniffi-bindgen -- \
        generate --library "$DYLIB_PATH" \
        --language swift \
        --out-dir "$OUTPUT_DIR"
)

echo "=== 完了: $OUTPUT_DIR ==="
ls -la "$OUTPUT_DIR"
