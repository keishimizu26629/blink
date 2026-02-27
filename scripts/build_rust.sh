#!/usr/bin/env bash
set -euo pipefail

# Rust core を arm64 + x86_64 でビルドし、universal binary を生成するスクリプト
# ビルド端末（Xcode搭載Mac）で実行する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PROJECT_ROOT/core"
OUTPUT_DIR="$PROJECT_ROOT/mac-ui/RustLib"

CRATE_NAME="core_api"
LIB_NAME="libcore_api.a"
UNIVERSAL_NAME="libcore_api_universal.a"

echo "=== Blink: Rust Core ビルド ==="
echo "プロジェクトルート: $PROJECT_ROOT"

# 出力ディレクトリ作成
mkdir -p "$OUTPUT_DIR"

# arm64 ビルド
echo "--- aarch64-apple-darwin ビルド ---"
cargo build --manifest-path "$CORE_DIR/Cargo.toml" \
    -p "$CRATE_NAME" \
    --release \
    --target aarch64-apple-darwin

# x86_64 ビルド
echo "--- x86_64-apple-darwin ビルド ---"
cargo build --manifest-path "$CORE_DIR/Cargo.toml" \
    -p "$CRATE_NAME" \
    --release \
    --target x86_64-apple-darwin

# universal binary 生成
echo "--- lipo: universal binary 生成 ---"
ARM64_LIB="$CORE_DIR/target/aarch64-apple-darwin/release/$LIB_NAME"
X86_64_LIB="$CORE_DIR/target/x86_64-apple-darwin/release/$LIB_NAME"

lipo -create "$ARM64_LIB" "$X86_64_LIB" -output "$OUTPUT_DIR/$UNIVERSAL_NAME"

echo "=== 完了: $OUTPUT_DIR/$UNIVERSAL_NAME ==="
lipo -info "$OUTPUT_DIR/$UNIVERSAL_NAME"
