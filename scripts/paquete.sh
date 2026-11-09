#!/bin/zsh
# paquete.sh: builds the installer package build/Haul-<version>.pkg.
#
# Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
# Date: November 9, 2026
# SPDX-License-Identifier: GPL-2.0-only
#
# This program is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License, version 2, as published by the Free Software Foundation.
# It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
#
# The package installs /Applications/Haul.app and then, as the owner of /opt/homebrew, installs or
# upgrades python, deno and ffmpeg (instalador/scripts/postinstall). It refuses to start without
# Homebrew. Its pages are in English and Spanish (instalador/resources/*.lproj); macOS Installer
# shows the language of the Mac. The package itself is not signed: that needs an Apple Developer ID.

set -euo pipefail
RAIZ="${0:A:h:h}"
cd "$RAIZ"

scripts/compilar.sh
export VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' build/Haul.app/Contents/Info.plist)
export YTDLP=$(<vendor/yt-dlp/VERSION)
# Fills in @VERSION@ and @YTDLP@ (values passed through the environment, never through a sed pattern).
rellenar() { perl -pe 's/\@VERSION\@/$ENV{VERSION}/g; s/\@YTDLP\@/$ENV{YTDLP}/g' "$1" > "$2" }

TRABAJO=build/pkg
rm -rf $TRABAJO
mkdir -p $TRABAJO/raiz/Applications $TRABAJO/recursos
ditto build/Haul.app $TRABAJO/raiz/Applications/Haul.app

# Never relocate: install to /Applications even if another copy is registered elsewhere.
pkgbuild --analyze --root $TRABAJO/raiz $TRABAJO/componente.plist >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO $TRABAJO/componente.plist

pkgbuild --root $TRABAJO/raiz --component-plist $TRABAJO/componente.plist \
    --identifier io.github.gabriel-castiglia.haul.pkg --version $VERSION \
    --install-location / --scripts instalador/scripts \
    $TRABAJO/Haul-component.pkg >/dev/null

for idioma in en es; do
    mkdir -p $TRABAJO/recursos/$idioma.lproj
    for f in instalador/resources/$idioma.lproj/*; do
        rellenar $f $TRABAJO/recursos/$idioma.lproj/${f:t}
    done
    cp LICENSE $TRABAJO/recursos/$idioma.lproj/License.txt
done
rellenar instalador/Distribution.xml $TRABAJO/Distribution.xml

SALIDA=build/Haul-$VERSION.pkg
productbuild --distribution $TRABAJO/Distribution.xml --resources $TRABAJO/recursos \
    --package-path $TRABAJO $SALIDA >/dev/null
rm -rf $TRABAJO

# Remove the build copy from the app register, so Spotlight lists only the installed one.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
$LSREGISTER -u "$RAIZ/build/Haul.app" 2>/dev/null || true
rm -rf build/Haul.app

echo "Built: $RAIZ/$SALIDA"
(cd build && shasum -a 256 ${SALIDA:t})
