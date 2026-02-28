#!/usr/bin/env bash
set -euo pipefail

# Blink.app を Remove→再配置→LaunchServices/Dock 更新するスクリプト
# 使い方:
#   ./scripts/deploy_app.sh                  # Release を /Applications に配置
#   ./scripts/deploy_app.sh Debug            # Debug を /Applications に配置
#   ./scripts/deploy_app.sh Release ~/Applications/Blink.app

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIGURATION="${1:-Release}"
DESTINATION="${2:-/Applications/Blink.app}"

case "$CONFIGURATION" in
    Debug|Release) ;;
    *)
        echo "エラー: Configuration は Debug または Release を指定してください"
        echo "例: ./scripts/deploy_app.sh Release"
        exit 1
        ;;
esac

SOURCE_APP="$PROJECT_ROOT/mac-ui/DerivedData/Build/Products/$CONFIGURATION/Blink.app"

if [ ! -d "$SOURCE_APP" ]; then
    echo "エラー: ビルド済みアプリが見つかりません: $SOURCE_APP"
    echo "先に xcodebuild で $CONFIGURATION ビルドを実行してください"
    exit 1
fi

echo "=== Blink: アプリ差し替えデプロイ ==="
echo "Configuration: $CONFIGURATION"
echo "Source      : $SOURCE_APP"
echo "Destination : $DESTINATION"

echo "--- 既存アプリ削除 ---"
rm -rf "$DESTINATION"

echo "--- アプリコピー ---"
cp -R "$SOURCE_APP" "$DESTINATION"

echo "--- タイムスタンプ更新 ---"
touch "$DESTINATION"

echo "--- LaunchServices 再登録 ---"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$DESTINATION"

echo "--- Dock 再起動 (アイコンキャッシュ更新) ---"
killall Dock || true

echo "=== 完了 ==="
echo "$DESTINATION"
