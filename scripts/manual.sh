#!/bin/zsh
# manual.sh: builds the PDF manuals from the READMEs.
#   README.md     -> docs/Haul-manual-en.pdf
#   README.es.md  -> docs/Haul-manual-es.pdf
#
# Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
# Date: October 19, 2026
# SPDX-License-Identifier: GPL-2.0-only
#
# This program is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License, version 2, as published by the Free Software Foundation.
# It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
#
# Requires pandoc (brew install pandoc) and Google Chrome, which prints the HTML to PDF.
# Run it again after every change to either README.

set -euo pipefail
RAIZ="${0:A:h:h}"
cd "$RAIZ"

REPO="https://github.com/Gabriel-Castiglia/haul"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

command -v pandoc >/dev/null || { echo "pandoc is missing: brew install pandoc" >&2; exit 1; }
[[ -x "$CHROME" ]] || { echo "Google Chrome is missing from /Applications" >&2; exit 1; }

TEMPORAL="$(mktemp -d)"
trap 'rm -rf "$TEMPORAL"' EXIT

# Cover block with icon, name and repository link.
cat > "$TEMPORAL/portada.html" <<HTML
<div class="portada">
  <img src="icono/icono-1024.png" alt="">
  <div>
    <p class="nombre">Haul</p>
    <p class="repo"><a href="$REPO">${REPO#https://}</a></p>
  </div>
</div>
HTML

# Relative links in the README (LICENSE, docs/…) point to the repository in the PDF; otherwise
# they would become file:// paths inside the temporary folder of whoever builds it.
cat > "$TEMPORAL/enlaces.lua" <<LUA
function Link(el)
  if not el.target:match("^%a[%w+.-]*:") and not el.target:match("^#") then
    el.target = "$REPO/blob/main/" .. el.target
  end
  return el
end
LUA

generar() {
    local fuente=$1 idioma=$2 titulo=$3 salida=$4
    # Self-contained HTML: stylesheet and icon embedded, no references to local files.
    pandoc "$fuente" --from gfm --to html5 --standalone --embed-resources \
        --lua-filter "$TEMPORAL/enlaces.lua" \
        --css docs/manual.css \
        --include-before-body "$TEMPORAL/portada.html" \
        --metadata pagetitle="$titulo" \
        --metadata lang="$idioma" \
        --output "$TEMPORAL/manual-$idioma.html"
    # No header or footer: Chrome would print the local path of the HTML file in them.
    "$CHROME" --headless --disable-gpu --no-pdf-header-footer \
        --print-to-pdf="$RAIZ/$salida" "file://$TEMPORAL/manual-$idioma.html" 2>/dev/null
    echo "Manual: $salida"
}

generar README.md    en "Haul · Manual"            docs/Haul-manual-en.pdf
generar README.es.md es "Haul · Manual de usuario" docs/Haul-manual-es.pdf
