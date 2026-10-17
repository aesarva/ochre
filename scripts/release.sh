#!/bin/bash
# Готовит релиз: universal-сборка, подпись Developer ID, нотаризация Apple, DMG.
#
#   scripts/release.sh 1.0.0             — полный релиз (нужны сертификат и профиль нотаризации)
#   scripts/release.sh 1.0.0 --unsigned  — проверка без сертификата: ad-hoc подпись, без нотаризации
#
# Однократная подготовка — см. раздел «Релиз» в README.md:
#   SIGN_IDENTITY   "Developer ID Application: Имя (TEAMID)" (по умолчанию ищется в связке ключей)
#   NOTARY_PROFILE  имя профиля из `xcrun notarytool store-credentials` (по умолчанию Ochre)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Использование: scripts/release.sh <версия> [--unsigned]}"
UNSIGNED=false
[ "${2:-}" = "--unsigned" ] && UNSIGNED=true
NOTARY_PROFILE="${NOTARY_PROFILE:-Ochre}"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if $UNSIGNED; then
    SIGN_IDENTITY="-"
elif [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "Нет сертификата «Developer ID Application» в связке ключей." >&2
        echo "Создайте его (README → «Релиз») или запустите с --unsigned для проверки." >&2
        exit 1
    fi
fi
echo "==> Подпись: $SIGN_IDENTITY"

# Временные каталоги удаляются и при сбое любого шага (set -e обрывает скрипт до rm -rf).
TMP_DIRS=()
cleanup() { if [ ${#TMP_DIRS[@]} -gt 0 ]; then rm -rf "${TMP_DIRS[@]}"; fi; }
trap cleanup EXIT

notarize() {
    echo "==> Нотаризация $(basename "$1")…"
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

echo "==> Сборка $VERSION"
VERSION="$VERSION" SIGN_IDENTITY="$SIGN_IDENTITY" scripts/build-app.sh
APP=build/Ochre.app

if ! $UNSIGNED; then
    # Приложение нотаризуем отдельно, чтобы скрепить билет с ним самим: тогда оно
    # открывается без сети, даже если пользователь скопирует его куда-то из DMG.
    ZIP_DIR="$(mktemp -d)"; TMP_DIRS+=("$ZIP_DIR")
    ZIP="$ZIP_DIR/Ochre.zip"
    ditto -c -k --keepParent "$APP" "$ZIP"
    notarize "$ZIP"
    xcrun stapler staple "$APP"
fi

mkdir -p dist
DMG="dist/Ochre-$VERSION.dmg"
STAGING="$(mktemp -d)"; TMP_DIRS+=("$STAGING")
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Ochre $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

if ! $UNSIGNED; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    echo "==> Проверка Gatekeeper"
    spctl --assess --type execute --verbose "$APP"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

# Копия без версии — на неё ведут кнопки «Скачать» на сайте (site/), кладётся рядом с index.html.
cp "$DMG" dist/Ochre.dmg

echo "==> Готово: $(pwd)/$DMG (и dist/Ochre.dmg для сайта)"
shasum -a 256 "$DMG"
