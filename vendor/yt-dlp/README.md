# yt-dlp 2026.08.19, bundled copy

English · [Español](README.es.md)

This folder holds an unmodified copy of [yt-dlp](https://github.com/yt-dlp/yt-dlp) version
2026.08.19. Descargador is built and tested with this exact version and runs it from inside the
app, so its behavior does not change when yt-dlp publishes a new release, and the project keeps
working even if the upstream repository becomes unavailable.

| File | Contents |
|---|---|
| `yt-dlp` | Official platform-independent zipimport executable; needs Python 3.10 or later |
| `yt-dlp.tar.gz` | Official source tarball of the same release |
| `SHA2-256SUMS`, `SHA2-256SUMS.sig` | Official checksums for the release and their signature |
| `public.key` | yt-dlp's public signing key |
| `VERSION` | Bundled version, read by `scripts/compilar.sh` |
| `licenses/` | License texts and the list of yt-dlp authors |

## Provenance

The files were downloaded on October 19, 2026 from the
[2026.08.19 release](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19). The SHA-256 hashes
of `yt-dlp` and `yt-dlp.tar.gz` match `SHA2-256SUMS`, and the signature on that file was verified
with the yt-dlp signing key `AC0C BBE6 848D 6A87 3464 AF4E 57CF 6593 3B5A 7581` (Simon Sawicki).
`scripts/compilar.sh` checks the hash of `yt-dlp` again on every build.

To verify by hand:

```
gpg --import public.key
gpg --verify SHA2-256SUMS.sig SHA2-256SUMS
shasum -a 256 --ignore-missing -c SHA2-256SUMS
```

## Credits and licenses

yt-dlp is developed by the yt-dlp contributors (see `licenses/yt-dlp-AUTHORS`) and is a fork of
youtube-dl. It is released into the public domain under the
[Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE) (`licenses/yt-dlp-LICENSE`).

The zipimport executable and the source tarball also include
[yt-dlp-ejs](https://github.com/yt-dlp/ejs) (Unlicense), which bundles:

- [meriyah](https://github.com/meriyah/meriyah), ISC license, copyright KFlash and others
  (`licenses/meriyah-LICENSE.md`);
- [astring](https://github.com/davidbonnet/astring), MIT license, copyright David Bonnet
  (`licenses/astring-LICENSE`).

These files keep their own licenses. Descargador's GPL-2.0-only license does not apply to them.

## Updating

`scripts/actualizar-yt-dlp.sh <version>` downloads another release, verifies its signature and
checksums, and replaces the files in this folder. Third-party license texts must then be checked
against the new release's README.
