# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org).

## [Unreleased]

## [0.1.3] - 2026-09-29

### Changed

- Releases now update the Homebrew cask automatically. No changes to the app itself.

## [0.1.2] - 2026-09-29

### Added

- In-app updates: a daily check of GitHub Releases, then one click to download, verify (SHA-256 against `SHA256SUMS.txt`, bundle id and version), sign locally and relaunch. Can be turned off in Settings → Updates.
- Homebrew tap: `brew install --cask simiriva95/tap/portpilot`, bumped by the release workflow.
- README install guide for Homebrew: setup, everyday commands and common errors.

## [0.1.1] - 2026-09-28

### Added

- Install guide for unsigned builds (remove quarantine, ad-hoc re-sign, Open Anyway), also shipped as `Install.txt` inside the DMG.
- `SHA256SUMS.txt` attached to every release.
- README screenshots, and a `-demo YES` launch argument with fake processes for taking them (quitting never sends a signal).

## [0.1.0] - 2026-09-28

### Added

- Menu bar panel listing every listening TCP port (optionally UDP), grouped by process, refreshed every 5 seconds.
- Detection of common dev servers (Vite, Next.js, Nuxt, Astro, Storybook, Angular, NestJS, Django, Rails, Laravel, .NET, Docker…) with the project folder, including servers started through `npx` or with a relative path.
- Quit with SIGTERM, Force Quit with SIGKILL when a process ignores it; confirmation for system and app processes.
- Processes of other users are listed with a lock and never signalled.
- Port clash highlighting, open in browser, copy port, URL, PID or command line.
- Keyboard navigation (`↑`/`↓`, `Return`, `⌘F`, `⌘R`, `Esc`), VoiceOver labels, Reduce Motion support.
- English and Italian localization.
- Launch at login.
- Universal `.dmg` and `.zip` built by `scripts/build-app.sh` and the release workflow.
- Quick quit shortcuts: `⌘⌫` quits the selected row, `⌥⌘⌫` force quits it, `⇧⌘⌫` quits all dev servers; `Return` confirms and `Esc` cancels, with a shortcut hint bar under the list.
- Themes (System, Synthwave, Terminal, Pastel, Sunset, Ocean) and a custom accent color.
- Pixel-art mascots (cat, penguin, fox, frog, bunny, panda, duck, owl, axolotl, capybara, dino, hedgehog, octopus) or a custom GIF: idle in the header, asleep in the empty state, cheering after a quit, hopping in the menu bar when the dev server count changes.

[Unreleased]: https://github.com/simiriva95/portpilot/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/simiriva95/portpilot/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/simiriva95/portpilot/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/simiriva95/portpilot/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/simiriva95/portpilot/releases/tag/v0.1.0
