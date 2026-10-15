#!/bin/bash
# Собирает build/Ochre.app (исполняемый модуль SwiftPM по-прежнему называется StatusApp).
#   ARCHS          архитектуры (по умолчанию "arm64 x86_64" — universal)
#   VERSION        версия для CFBundleShortVersionString (по умолчанию — из Resources/Info.plist)
#   SIGN_IDENTITY  сертификат подписи, например "Developer ID Application: Имя (TEAMID)";
#                  по умолчанию "-" — подпись ad-hoc для локального запуска
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

ARCHS="${ARCHS:-arm64 x86_64}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ARCH_FLAGS=()
for arch in $ARCHS; do ARCH_FLAGS+=(--arch "$arch"); done

swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

APP=build/Ochre.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/StatusApp" "$APP/Contents/MacOS/Ochre"
cp Resources/Info.plist "$APP/Contents/Info.plist"

PLIST="$APP/Contents/Info.plist"
if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
fi
# Номер сборки растёт с каждым коммитом — macOS и Sparkle сравнивают по нему.
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"

# Иконка — документ Icon Composer: actool собирает Assets.car (маска и стекло macOS 26+)
# и AppIcon.icns. Старая .icns без формата .icon попадает в серую подложку на мелких размерах.
ICON_TMP="$(mktemp -d)"
xcrun actool Resources/AppIcon.icon --compile "$APP/Contents/Resources" --platform macosx \
    --minimum-deployment-target 26.0 --app-icon AppIcon \
    --output-partial-info-plist "$ICON_TMP/partial.plist" >/dev/null
rm -rf "$ICON_TMP"

# Hardened runtime обязателен для нотаризации; включаем его и в ad-hoc сборке,
# чтобы локально проверять то же поведение, что получат пользователи.
SIGN_FLAGS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" != "-" ]; then SIGN_FLAGS+=(--timestamp); fi
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --strict "$APP"
echo "$(pwd)/$APP"
