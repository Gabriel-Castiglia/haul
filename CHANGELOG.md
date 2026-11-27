# Changelog

All notable changes to Haul. Versions follow [semantic versioning](https://semver.org): major.minor.patch.

## 1.8.1 - 2026-11-27

The rest of what Haul 1.8.0 for Windows brought, where it applies on the Mac.

### Added

- Rows of the queue can be moved one place with Move up and Move down in the row's menu (right-click), and VoiceOver
  offers the same two actions, besides dragging with the mouse.
- On the first start Haul follows the Mac when it is in Spanish or Japanese, and is in English otherwise.

### Changed

- "Check for updates" asked again while a check or an update is under way says so; before, it did nothing.
- The red of a failed row is darker on a light window and brighter on a dark one, so it reads at 4.5:1 or more in both.

### Fixed

- A row whose last attempt failed turned red while yt-dlp was still running, and could be removed or retried under
  it. It now turns red when yt-dlp exits.
- "Cancel all" with "Clear finished automatically" on removes the cancelled rows, as a single cancel already did.

## 1.8.0 - 2026-11-27

What Haul 1.8.0 for Windows brought, on the Mac.

### Added

- **Japanese interface**: Haul speaks Japanese too (日本語 in the Language menu), with the texts of Haul for Windows
  where both have the same one. The installer pages are in Japanese on a Mac in Japanese.
- The README and the PDF manual are also in Japanese (`README.ja.md`, `docs/Haul-manual-ja.pdf`), and the pictures of
  the window are in the three languages.

### Changed

- "Video", the name of the format, is translated like the rest of the window.
- The README describes the safeguards of 1.7.0 (`--ignore-config`, only Haul's plugins) and no longer mentions the
  eagle of the old icon.

## 1.7.0 - 2026-11-27

### Security

- yt-dlp always runs with `--ignore-config`. Before, it read a `yt-dlp.conf` from the download folder (its working
  directory, usually Downloads, where any web page can leave a file), and options in it such as `--exec` would run
  commands. As a consequence, the user's own yt-dlp configuration files (`~/.config/yt-dlp/config` and the like) are
  no longer applied either.
- yt-dlp loads only Haul's own plugins (`--no-plugin-dirs`, then `--plugin-dirs` with Haul's `plugins` folder).
  Before, it also loaded any plugin in `~/.config/yt-dlp/plugins` and its other default folders, where any program
  run by the user can leave Python code.
- Thumbnails are shown only from `http` and `https` addresses; local paths are ignored.

### Changed

- The Spanish texts address the user as "tú" in neutral Spanish, as Haul for Windows does: for example "Pega uno o
  varios enlaces", "Reanudar todo" (was "Seguir todo"), "Descargar listas enteras" (was "Bajar listas enteras") and
  "Quitar de la cola" (was "Sacar de la cola").

## 1.6.2 - 2026-11-27

### Changed

- **A new icon**: a download arrow going into a tray, drawn as a flat picture, cream with a black outline on the
  chosen colour, with the play sign of a video. It replaces the engraving of an eagle carrying a hare, and still
  follows the colour chosen in the settings, in all twelve colours. The drawing is in `assets/icon.svg`.

## 1.6.1 - 2026-11-25

### Changed

- Bundles **yt-dlp 2026.11.23** (it was 2026.08.19), unmodified, with its signature and checksums verified against
  the key of yt-dlp's releases (`AC0C BBE6 848D 6A87 3464 AF4E 57CF 6593 3B5A 7581`). Sites change often and an old
  yt-dlp stops working with them; checked with a real download from YouTube and Vimeo's player.
- The release carries `release.sig`, the author's signature of its `SHA256SUMS.txt`, like the Windows apps. Haul for
  Mac already accepts an update only when the downloaded app is signed as the installed one.
- Building the manuals stops when the version of Haul or of yt-dlp written under the title of a README is not the
  real one.

## 1.6.0 - 2026-11-20

What Haul 1.7.0 for Windows brought, on the Mac.

### Added

- Updates that install themselves. Once a day, or with "Check for updates" in About Haul, Haul asks GitHub for
  its latest release and, if it is newer, asks once: "Update now", "What's new" or "Later". "Update now" downloads
  the package, checks it against the release's `SHA256SUMS.txt` (a file that does not match is deleted and never
  opened) and the app inside it for the same identifier, version and signature, asks what to do with a running
  download (update now or when the queue ends), saves the queue, quits, puts the new app in place and opens it.
- yt-dlp updates from the app. Once a day (it can be turned off in About Haul) and with "Update yt-dlp", Haul
  fetches yt-dlp's latest official release into `~/Library/Application Support/Haul/yt-dlp/<version>`, checks it
  against `SHA2-256SUMS` and its own version number, and uses it for the next downloads; a running download keeps
  the copy it started with. The copy inside the app stays as it was.
- The queue survives quitting Haul: queued, paused and failed rows and the links still waiting come back in the
  same order; a download that was running comes back queued and resumes from its partial files. It is saved in
  `~/Library/Application Support/Haul/queue.json` through a temporary file; a damaged file is set aside as
  `queue.damaged.json`.
- `Haul --self-test` checks the saved queue, the version logic of Haul and yt-dlp and the checksum lists with
  throw-away data, before any window exists and without touching the user's settings or queue; the exit code is
  the number of failures. `--red` adds a real yt-dlp update into the temporary folder.

### Fixed

- Quitting Haul while a download was running left yt-dlp downloading on its own. It is now stopped at quit,
  and the download comes back queued.

### Not brought over

- The compact window of the Windows version, made for 1366 × 768 screens at 125 % or 150 %: the smallest Mac
  screen holds the window as it is.

## 1.5.1 - 2026-11-11

### Fixed

- The icon in the Dock kept the default orange while Haul was open with another colour: it was set before the
  Dock tile existed. It is now set again once Haul has started.
- The README explains how to empty the Dock's icon cache when it keeps showing an old icon.

## 1.5.0 - 2026-11-11

### Added

- Light, dark or as macOS, from the new Appearance menu, also behind the palette button of the window. A Haul
  that already ran keeps the dark window it had; a new installation follows macOS.
- Twelve colours for the buttons, check boxes, selected items and the icon in the Dock. Before, the window took
  the accent colour of macOS.
- Notice of new versions: once a day Haul asks GitHub for the latest version number and, if it is newer,
  offers to open the download page. About Haul turns it off and asks on request.
- Pictures of the window in the README.

### Changed

- A new icon: the eagle carrying a hare from an engraving by the Monogrammist B (Italy, 17th century;
  Rijksmuseum, public domain), drawn by `scripts/make_icon.py` in the twelve colours, orange by default.
- The README and the manuals say Apple silicon (arm64) only and link to the latest release.

## 1.4.1 - 2026-11-09

### Added

- Installer package, `Haul-<version>.pkg`, in English and Spanish, built by `scripts/paquete.sh`. It
  installs the app and installs or upgrades Python, deno and ffmpeg with Homebrew.
- This changelog.

## 1.4.0 - 2026-10-26

### Added

- Pause for each row and for the whole queue; partial files are kept and the download resumes.
- Retry all failed downloads with one button.
- Drag rows to change the order of the queue.
- "Download whole playlists" setting, instead of a question every time.

### Changed

- Everything down to the Download button stays fixed; only the queue scrolls.
- The technical log and the tagline under the title were removed.

### Fixed

- Posts that link to an unlisted video instead of embedding it now download.

## 1.3.0 - 2026-10-24

### Added

- Haul's own yt-dlp plugin, for links the bundled yt-dlp does not handle.

### Changed

- The window is always dark, whatever the system appearance.
- The documentation and the messages describe Haul as a front end for yt-dlp, without naming sites.

## 1.2.1 - 2026-10-21

### Changed

- "Clear finished automatically" is a checkbox below the format, always visible; it used to sit in the
  queue header, which hides when the queue is empty.

### Fixed

- The link box no longer fills again with the same link when the window comes back to the front.

## 1.2.0 - 2026-10-21

### Added

- A failed download or playlist read is tried again up to four times, two seconds apart.
- Finished and cancelled rows can leave the list by themselves.
- Downloads with "instrumental" in the title wait paused unless "Download instrumentals" is checked.

### Changed

- The header stays fixed while the rest of the window scrolls.

### Fixed

- Intermediate files that yt-dlp could not delete, because another program held them open, are
  removed after the download.

## 1.1.0 - 2026-10-20

### Added

- Playlist and channel links are expanded into one row per item, saved in a subfolder named after the
  list and numbered in its order.
- Cancelling stops yt-dlp and ffmpeg and deletes only the files that download created.
- About window with the version, the meaning of the name, the author, the license and the repositories.

### Changed

- The project is called Haul; it was Descargador until 1.0.0. The old repository address redirects.

## 1.0.0 - 2026-10-19

First release.

- Download queue: paste several links at once; they are downloaded one at a time.
- Formats: video (MP4, H.264/AAC) and audio only (MP3).
- Remembers the destination folder, the format and the window size.
- English and Spanish interface, chosen from the Language menu; English by default.
- Bundles yt-dlp 2026.08.19, unmodified, with its signature and checksums verified;
  `scripts/actualizar-yt-dlp.sh` moves it to another release.
- Installer script that installs or upgrades Python, deno and ffmpeg with Homebrew.
- Stable local code signature, so macOS keeps the permissions granted.
- README and PDF manual in English and Spanish.
