#!/bin/zsh
# actualizar-yt-dlp.sh: replaces the bundled yt-dlp in vendor/yt-dlp with another official release.
#
# Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
# Date: October 19, 2026
# SPDX-License-Identifier: GPL-2.0-only
#
# This program is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License, version 2, as published by the Free Software Foundation.
# It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
#
# Usage: scripts/actualizar-yt-dlp.sh <version>      e.g. scripts/actualizar-yt-dlp.sh 2026.09.30
#
# Downloads the release's zipimport executable, source tarball, checksums and signature; checks
# the signature with the key already stored in vendor/yt-dlp/public.key and the SHA-256 hashes;
# only then replaces the files. Afterwards: review licenses/, update the version in both READMEs
# and in vendor/yt-dlp/README*.md, test, and rebuild with scripts/instalar.sh.

set -euo pipefail
(( $# == 1 )) || { echo "Usage: $0 <version>" >&2; exit 2; }
VERSION=$1
RAIZ="${0:A:h:h}"
DESTINO="$RAIZ/vendor/yt-dlp"
URL="https://github.com/yt-dlp/yt-dlp/releases/download/$VERSION"

TEMPORAL="$(mktemp -d)"
trap 'rm -rf "$TEMPORAL"' EXIT
cd "$TEMPORAL"

for archivo in yt-dlp yt-dlp.tar.gz SHA2-256SUMS SHA2-256SUMS.sig; do
    curl -fsSL -o "$archivo" "$URL/$archivo"
done

# Signature: the key is the one already trusted in the repository, not a fresh download.
export GNUPGHOME="$TEMPORAL/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --quiet --import "$DESTINO/public.key" 2>/dev/null
gpg --verify SHA2-256SUMS.sig SHA2-256SUMS
grep -E ' (yt-dlp|yt-dlp\.tar\.gz)$' SHA2-256SUMS | shasum -a 256 -c -

# License files from the source tarball.
mkdir fuente
tar -xzf yt-dlp.tar.gz -C fuente yt-dlp/LICENSE yt-dlp/AUTHORS

cp yt-dlp yt-dlp.tar.gz SHA2-256SUMS SHA2-256SUMS.sig "$DESTINO/"
cp fuente/yt-dlp/LICENSE "$DESTINO/licenses/yt-dlp-LICENSE"
cp fuente/yt-dlp/AUTHORS "$DESTINO/licenses/yt-dlp-AUTHORS"
chmod +x "$DESTINO/yt-dlp"
echo "$VERSION" > "$DESTINO/VERSION"

echo "vendor/yt-dlp now holds yt-dlp $VERSION."
echo "Next: review vendor/yt-dlp/licenses, update the version in the READMEs, then scripts/instalar.sh"
