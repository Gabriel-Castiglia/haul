# firma.sh: stable local code-signing identity for Descargador.
#
# Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
# Date: October 19, 2026
# SPDX-License-Identifier: GPL-2.0-only
#
# This program is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License, version 2, as published by the Free Software Foundation.
# It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
#
# macOS ties the permissions a user grants (folders, clipboard) to the app's signing identity.
# An ad hoc signature changes on every build and forces the user to grant them again; a fixed,
# self-issued certificate keeps the same identity across builds.
#
# The first run creates:
#   - a self-signed code-signing certificate, valid for ten years;
#   - a dedicated keychain that holds it ($LLAVERO);
#   - that keychain's password, stored in the login keychain ($SERVICIO).
#
# This file is sourced by compilar.sh; it is not meant to be run on its own.

IDENTIDAD="Descargador (firma local)"
LLAVERO="$HOME/Library/Keychains/descargador-firma.keychain-db"
SERVICIO="descargador-firma-local"
OPENSSL=/usr/bin/openssl   # system LibreSSL: produces PKCS#12 files that `security import` accepts

preparar_firma() {
    local clave temporal

    if [[ ! -f "$LLAVERO" ]]; then
        echo "Creating signing identity \"$IDENTIDAD\"…"
        clave=$($OPENSSL rand -hex 24)
        security add-generic-password -U -s "$SERVICIO" -a "$USER" -w "$clave"
        security create-keychain -p "$clave" "$LLAVERO"
        security set-keychain-settings "$LLAVERO"   # no automatic locking

        temporal=$(mktemp -d)
        $OPENSSL req -x509 -newkey rsa:2048 -nodes -days 3650 \
            -keyout "$temporal/clave.pem" -out "$temporal/certificado.pem" \
            -subj "/CN=$IDENTIDAD" \
            -addext "keyUsage=critical,digitalSignature" \
            -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1
        $OPENSSL pkcs12 -export -inkey "$temporal/clave.pem" -in "$temporal/certificado.pem" \
            -out "$temporal/identidad.p12" -passout pass:temporal
        security import "$temporal/identidad.p12" -k "$LLAVERO" -P temporal -T /usr/bin/codesign >/dev/null
        # Lets codesign use the key without showing a dialog.
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$clave" "$LLAVERO" >/dev/null
        rm -rf "$temporal"
    fi

    clave=$(security find-generic-password -s "$SERVICIO" -a "$USER" -w)
    security unlock-keychain -p "$clave" "$LLAVERO"
}
