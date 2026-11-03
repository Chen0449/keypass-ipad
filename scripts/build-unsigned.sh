#!/bin/bash
# 在 macOS 上本地打未签名 IPA（和 GitHub Actions 里的步骤完全一致）
# 用法: ./scripts/build-unsigned.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，先跑: brew install xcodegen"
  exit 1
fi

xcodegen generate

xcodebuild \
  -project KeyPass.xcodeproj \
  -scheme KeyPassHost \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  build

APP_PATH="build/Build/Products/Release-iphoneos/KeyPassHost.app"
test -d "$APP_PATH" || { echo "找不到 $APP_PATH"; exit 1; }
test -d "$APP_PATH/PlugIns/KeyPassKeyboard.appex" || { echo "扩展没有进 PlugIns"; exit 1; }

rm -rf out
mkdir -p out/Payload
cp -R "$APP_PATH" out/Payload/
cd out
zip -qry KeyPass-unsigned.ipa Payload

echo "OK -> $(pwd)/KeyPass-unsigned.ipa"
