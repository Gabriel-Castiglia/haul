#!/bin/zsh
# instalar.sh: installs or updates the dependencies, builds Descargador and copies it to /Applications.
#
# Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
# Date: October 19, 2026
# SPDX-License-Identifier: GPL-2.0-only
#
# This program is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License, version 2, as published by the Free Software Foundation.
# It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
#
# yt-dlp itself is not installed: the app bundles the pinned copy in vendor/yt-dlp.
# Dependencies it manages (through Homebrew):
#   python  runs the bundled yt-dlp (3.10 or later)
#   deno    JavaScript runtime that yt-dlp needs for full YouTube support
#   ffmpeg  merges picture and sound, and converts to MP3
# If they are already installed, they are upgraded to the latest version.

set -euo pipefail
RAIZ="${0:A:h:h}"
BREW=/opt/homebrew/bin/brew
DESTINO=/Applications/Descargador.app

if [[ ! -x $BREW ]]; then
    echo "Homebrew is missing. See https://brew.sh" >&2
    exit 1
fi

# Prevents Homebrew from removing other dependencies it considers orphaned.
export HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_ENV_HINTS=1

for paquete in python deno ffmpeg; do
    if $BREW list --formula "$paquete" >/dev/null 2>&1; then
        echo "Upgrading $paquete…"
        $BREW upgrade "$paquete" 2>&1 | grep -v "already installed" || true
    else
        echo "Installing $paquete…"
        $BREW install "$paquete"
    fi
done

"$RAIZ/scripts/compilar.sh"

# Quit the app if it is running before replacing it.
osascript -e 'if application "Descargador" is running then tell application "Descargador" to quit' >/dev/null 2>&1 || true

rm -rf "$DESTINO"
ditto "$RAIZ/build/Descargador.app" "$DESTINO"
touch "$DESTINO"   # makes the Finder and the Dock refresh the icon

echo
echo "Installed at $DESTINO"
echo "  yt-dlp $(/opt/homebrew/bin/python3 "$DESTINO/Contents/Resources/yt-dlp" --version) (bundled)"
echo "  $(/opt/homebrew/bin/python3 --version), deno $(/opt/homebrew/bin/deno --version | head -1 | cut -d' ' -f2)"
echo "  $(/opt/homebrew/bin/ffmpeg -version | head -1 | cut -d' ' -f1-3)"
