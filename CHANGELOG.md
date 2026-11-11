# Changelog

All notable changes to Haul. Versions follow [semantic versioning](https://semver.org): major.minor.patch.

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
