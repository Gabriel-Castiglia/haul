# Descargador

Gabriel Castiglia · October 19, 2026 · version 1.0.0 · GPL-2.0 license · built and tested with yt-dlp 2026.08.19

English · [Español](README.es.md)

Repository: <https://github.com/Gabriel-Castiglia/descargador>

PDF manual: [`docs/Descargador-manual-en.pdf`](docs/Descargador-manual-en.pdf)

Descargador is a macOS app that downloads video and audio from YouTube and every other site
supported by [yt-dlp](https://github.com/yt-dlp/yt-dlp). The app builds the command, shows the
progress and manages a download queue. The actual work is done by yt-dlp, bundled with the app at
a fixed, verified version, and by ffmpeg, installed with Homebrew. The interface is available in English and Spanish, selectable from the Language
menu; it starts in English on first launch and remembers the choice.

## Requirements

- macOS 15 or later, on a Mac with Apple silicon. Tested on macOS 27.
- [Homebrew](https://brew.sh) in `/opt/homebrew`.
- Apple's Command Line Tools (`xcode-select --install`). Xcode is not needed.

yt-dlp ships with the app. Python, deno and ffmpeg are installed by the installer, so nothing has to be
installed by hand.

## Installation

```
git clone https://github.com/Gabriel-Castiglia/descargador.git
cd descargador
scripts/instalar.sh
```

The installer:

1. installs Python, deno and ffmpeg with Homebrew or, if they are already present, upgrades them;
2. builds the app, checks the bundled yt-dlp against its official checksums, and signs the app with
   the local identity (see "Signing and permissions");
3. copies it to `/Applications/Descargador.app`, quitting it first if it is running.

Running it again is how everything gets updated, dependencies and app alike.

## Usage

1. Paste one or more links into the box at the top. Links can be pasted on their own, one per
   line, or inside text copied from somewhere else; the app extracts them and drops duplicates. If
   clipboard access is allowed, the app picks up a copied link by itself when it opens.
2. Choose the format: Video (MP4) or Audio only (MP3).
3. Choose the destination folder. The first time it is Downloads; after that the app keeps the
   last folder chosen, and the format too.
4. Press Download or ⌘↩.

Links go into a queue and are downloaded one at a time. More links can be added while the queue
runs. Each row shows the thumbnail, title, percentage, speed and time remaining, and once finished
it offers to reveal the file in the Finder or open it. Failed or cancelled downloads can be retried
or removed. The full yt-dlp output is under "Technical details".

The app can also be started with links from Terminal or from Shortcuts:

```
open -a Descargador --args --descargar URL1 URL2
```

## Formats

| Format | Result | yt-dlp options |
|---|---|---|
| Video | MP4 with H.264 and AAC, up to 1080p on YouTube | `-f bv*+ba/b -S vcodec:h264,res,acodec:aac --merge-output-format mp4` |
| Audio only | MP3 at the highest quality | `-x --audio-format mp3 --audio-quality 0` |

H.264 is preferred because QuickTime and iOS play it without conversion; without that preference
YouTube serves AV1 with Opus audio. Files are named after the video title. A link that points into
a playlist downloads only that video.

## Repository layout

| Path | Contents |
|---|---|
| `fuentes/Descargador.swift` | App source code (SwiftUI, a single file) |
| `icono/icono.html` | Icon as SVG |
| `icono/icono-1024.png` | Rendered icon, source for every size |
| `scripts/instalar.sh` | Dependencies, build and installation |
| `scripts/compilar.sh` | Build and signing into `build/` |
| `scripts/firma.sh` | Local signing identity (sourced by `compilar.sh`) |
| `scripts/manual.sh` | Builds the PDF manuals from the READMEs |
| `scripts/actualizar-yt-dlp.sh` | Replaces the bundled yt-dlp with another verified release |
| `vendor/yt-dlp/` | Bundled copy of yt-dlp 2026.08.19, with sources, checksums, signature and licenses |
| `docs/Descargador-manual-en.pdf`, `docs/Descargador-manual-es.pdf` | PDF manuals, in English and Spanish |
| `docs/manual.css` | Stylesheet for the manuals |
| `README.md`, `README.es.md` | This documentation, in English and Spanish |

The `build/` folder is generated at build time and is not part of the repository.

## Signing and permissions

macOS stores the permissions a user grants, such as access to Downloads or to the clipboard,
together with the app's signature. An ad hoc signature changes on every build, so macOS asks for
them again. That is why the project signs with its own stable certificate, "Descargador (firma
local)", which `scripts/firma.sh` creates the first time on the Mac where the app is built:

- the certificate and its key live in a dedicated keychain,
  `~/Library/Keychains/descargador-firma.keychain-db`;
- that keychain's password lives in the login keychain, under the name `descargador-firma-local`.

With that signature, permissions granted once are kept across versions. The certificate exists
only on the Mac where it was created: a built copy taken to another Mac must be opened the first
time with right-click and Open.

Automatic pasting of links when the app opens works only if clipboard access is set to "Always
Allow" (System Settings, Privacy & Security, Paste from Other Apps). Without that permission the
app reads the clipboard only when Paste is pressed, and shows no prompt when it opens.

## Icon

The interface takes the system accent color and follows it when it changes. The icon, on the
other hand, is fixed (graphite with the current accent green), because an icon that adapts to the
system theme requires the Icon Composer format and Xcode. To change its colors, edit the
`stop-color` values in `icono/icono.html`, render the PNG again and reinstall:

```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=512,512 --default-background-color=00000000 \
  --screenshot="$PWD/icono/icono-1024.png" "file://$PWD/icono/icono.html"
scripts/instalar.sh
```

If the Dock keeps showing the old icon, remove the app from the Dock and add it again.

## Maintenance

Descargador is built and tested with yt-dlp 2026.08.19, and that exact copy ships inside the app.
A pinned version keeps the behavior stable and does not depend on the yt-dlp repository staying
online. The trade-off is that YouTube changes often, and sooner or later a fixed version stops
working with it. When that happens, a new release of Descargador moves to a newer yt-dlp:

```
scripts/actualizar-yt-dlp.sh <version>
scripts/instalar.sh
```

The first script downloads the release, verifies its signature with the key stored in
`vendor/yt-dlp/public.key` and its SHA-256 checksums, and only then replaces the files. Running
`scripts/instalar.sh` again also upgrades Python, deno and ffmpeg.

The most common yt-dlp errors are shown in plain words in the interface language (video
unavailable, private video, unsupported site, no connection); anything else appears exactly as
yt-dlp prints it.

Preferences (language, folder, format, window size) are stored in the
`io.github.gabriel-castiglia.descargador` domain. They can be reset with
`defaults delete io.github.gabriel-castiglia.descargador`.

## Technical notes

The app runs the bundled yt-dlp with Homebrew's Python as a child process and adds
`/opt/homebrew/bin` to `PATH`, because an app launched from the Finder does not inherit the
Terminal's and would not find deno or ffmpeg. To avoid
depending on the text yt-dlp prints for the Terminal, it asks for output in a custom,
tab-separated format:

| Line | Contents | Source |
|---|---|---|
| `INFO` | title, uploader, duration and thumbnail | `-O before_dl:…` |
| `AVANCE` | percentage, speed and time remaining | `--progress-template` |
| `ARCHIVO` | final file path | `-O after_move:…` |

Building without Xcode imposes two limitations, both handled in the code. First, SwiftUI's
`@State` macro is unavailable, because its plugin ships only with Xcode; the code uses
`@StateObject` with the `Marca` class instead. Second, with a hidden title bar SwiftUI ignores
`.defaultSize`, so the initial window size is set through AppKit in
`applicationDidFinishLaunching`.

## Credits

Descargador is a front end; the hard work belongs to these projects:

| Project | Role in Descargador | License |
|---|---|---|
| [yt-dlp](https://github.com/yt-dlp/yt-dlp), by the yt-dlp contributors, fork of youtube-dl | Download engine, bundled in `vendor/yt-dlp` | [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE) |
| [yt-dlp-ejs](https://github.com/yt-dlp/ejs), included in the yt-dlp executable | YouTube JavaScript challenge solver | Unlicense |
| [meriyah](https://github.com/meriyah/meriyah), by KFlash and others, inside yt-dlp-ejs | JavaScript parser | [ISC](https://github.com/meriyah/meriyah/blob/main/LICENSE.md) |
| [astring](https://github.com/davidbonnet/astring), by David Bonnet, inside yt-dlp-ejs | JavaScript code generator | [MIT](https://github.com/davidbonnet/astring/blob/main/LICENSE) |
| [FFmpeg](https://ffmpeg.org), installed with Homebrew, not bundled | Merges picture and sound, converts to MP3 | [LGPL-2.1+ / GPL-2.0+](https://ffmpeg.org/legal.html), depending on the build |
| [Deno](https://deno.com), installed with Homebrew | JavaScript runtime used by yt-dlp for YouTube | [MIT](https://github.com/denoland/deno/blob/main/LICENSE.md) |
| [Python](https://www.python.org), installed with Homebrew | Runs yt-dlp | [PSF License](https://docs.python.org/3/license.html) |
| [Homebrew](https://brew.sh) | Installs the dependencies | [BSD-2-Clause](https://github.com/Homebrew/brew/blob/master/LICENSE.txt) |
| [pandoc](https://pandoc.org), only to build the PDF manuals | Markdown to HTML conversion | [GPL-2.0+](https://github.com/jgm/pandoc/blob/main/COPYRIGHT) |

The license texts of the bundled components are in `vendor/yt-dlp/licenses/` and are copied into
the app, under `Contents/Resources/licenses/`.

## License

Copyright (C) 2026 Gabriel Castiglia.

Descargador is free software, released under the GNU General Public License, version 2
(GPL-2.0-only), the same license as the Linux kernel. It may be used, studied, modified and
redistributed; any modified version that is distributed must be released under the same license,
together with its source code. The full text is in [`LICENSE`](LICENSE).

Descargador includes an unmodified copy of yt-dlp in `vendor/yt-dlp`, which keeps its own licenses
(Unlicense, with ISC and MIT components) and is not covered by the GPL. Descargador runs yt-dlp
and ffmpeg as separate programs and does not link to them; ffmpeg is not bundled.
