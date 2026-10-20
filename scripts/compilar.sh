#!/bin/zsh
# compilar.sh: builds Haul and produces a signed build/Haul.app.
#
# Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
# Date: October 19, 2026
# SPDX-License-Identifier: GPL-2.0-only
#
# This program is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License, version 2, as published by the Free Software Foundation.
# It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
#
# Requires Apple's Command Line Tools (xcode-select --install); Xcode is not needed.

set -euo pipefail
RAIZ="${0:A:h:h}"
cd "$RAIZ"
source scripts/firma.sh

VERSION="1.2.0"
COMPILACION="3"
APP="build/Haul.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Binary
swiftc -O -swift-version 5 -parse-as-library \
    -o "$APP/Contents/MacOS/Haul" fuentes/Haul.swift

# 2. Icon: every size macOS expects, generated from the 1024 px PNG
SET="$(mktemp -d)/Haul.iconset"
mkdir -p "$SET"
for t in 16 32 128 256 512; do
    sips -z $t $t icono/icono-1024.png --out "$SET/icon_${t}x${t}.png" >/dev/null
    sips -z $((t * 2)) $((t * 2)) icono/icono-1024.png --out "$SET/icon_${t}x${t}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/Haul.icns"
rm -rf "${SET:h}"

# 3. Bundled yt-dlp: verify it against the official checksums, then copy it with its licenses
YTDLP_VERSION="$(<vendor/yt-dlp/VERSION)"
if ! (cd vendor/yt-dlp && grep -E ' yt-dlp$' SHA2-256SUMS | shasum -a 256 -c --status -); then
    echo "vendor/yt-dlp/yt-dlp does not match SHA2-256SUMS; refusing to build." >&2
    exit 1
fi
cp vendor/yt-dlp/yt-dlp "$APP/Contents/Resources/yt-dlp"
mkdir -p "$APP/Contents/Resources/licenses"
cp vendor/yt-dlp/licenses/* "$APP/Contents/Resources/licenses/"
cp LICENSE "$APP/Contents/Resources/licenses/Haul-LICENSE"

# 4. Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Haul</string>
    <key>CFBundleDisplayName</key><string>Haul</string>
    <key>CFBundleIdentifier</key><string>io.github.gabriel-castiglia.haul</string>
    <key>CFBundleExecutable</key><string>Haul</string>
    <key>CFBundleIconFile</key><string>Haul</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$COMPILACION</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
    <key>NSHumanReadableCopyright</key><string>© 2026 Gabriel Castiglia · GPL-2.0 · yt-dlp $YTDLP_VERSION (Unlicense)</string>
    <key>YtDlpVersion</key><string>$YTDLP_VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 5. Sign with the stable identity (see scripts/firma.sh)
preparar_firma
codesign --force --sign "$IDENTIDAD" --keychain "$LLAVERO" --timestamp=none "$APP"

echo "Built: $RAIZ/$APP (version $VERSION, yt-dlp $YTDLP_VERSION)"
