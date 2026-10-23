#!/bin/bash
# Печатает ленту обновлений Sparkle (appcast.xml) для одного релиза.
#
#   scripts/make-appcast.sh dist/Ochre-1.1.0.dmg 1.1.0 120 > dist/appcast.xml
#
# DMG подписывается ключом EdDSA из связки ключей (sign_update из Sparkle). Файл прикрепляется к релизу
# на GitHub рядом с DMG: приложение читает его по ссылке releases/latest/download/appcast.xml.
set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:?Использование: scripts/make-appcast.sh <dmg> <версия> <номер сборки>}"
VERSION="${2:?нет версии}"
BUILD="${3:?нет номера сборки}"

SIGN_UPDATE="$(find .build -type f -path '*/Sparkle/bin/sign_update' 2>/dev/null | head -1)"
if [ -z "$SIGN_UPDATE" ]; then
    echo "Нет sign_update: сначала swift package resolve" >&2
    exit 1
fi
# Печатает атрибуты sparkle:edSignature="…" length="…" для <enclosure>.
SIG_ATTRS="$("$SIGN_UPDATE" "$DMG")"

REPO=https://github.com/aesarva/ochre
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Ochre</title>
    <link>$REPO</link>
    <item>
      <title>Ochre $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <link>$REPO/releases/tag/v$VERSION</link>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <enclosure url="$REPO/releases/download/v$VERSION/Ochre-$VERSION.dmg" type="application/octet-stream" $SIG_ATTRS/>
    </item>
  </channel>
</rss>
EOF
