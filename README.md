# PortPilot

A tiny native macOS menu bar app that shows every listening port, grouped by process — and lets you quit the dev server hogging `:3000` in one click.

- **Grouped by process**: `Vite — frontend-admin`, `Next.js`, `service-scope (.NET)`, `postgres`, `Docker`… with the port numbers front and center.
- **Knows your stack**: detects Vite, Next.js, Nuxt, Astro, Storybook, Angular, NestJS, Django, Rails, Laravel, .NET, Docker and more, and shows the project folder the server was started from.
- **Quit safely**: SIGTERM first, Force Quit (SIGKILL) only if the process ignores it. System and app processes always ask first; processes of other users are shown locked.
- **Open in browser**: click a port chip to open `http://localhost:<port>`, right-click to copy.
- **Port clashes**: highlights ports bound by two processes (hello, AirPlay Receiver on 5000).
- Native SwiftUI, light & dark mode, no dependencies, ~1 MB. macOS 13 Ventura or later.

## Install

Download the latest `.dmg` from [Releases](https://github.com/simiriva95/portpilot/releases), drag PortPilot to Applications and open it.

If a build is not notarized, macOS blocks the first launch. Right-click the app → **Open**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/PortPilot.app
```

## Build from source

```sh
git clone https://github.com/simiriva95/portpilot.git
cd portpilot
swift run                     # debug run (menu bar icon appears, no Dock icon when bundled)
./scripts/build-app.sh        # universal PortPilot.app + .zip + .dmg in ./dist
```

Open `Package.swift` in Xcode to work on it with previews and the debugger.

## How it works

PortPilot runs `lsof -nP -iTCP -sTCP:LISTEN` (plus `-iUDP` if enabled), reads each process's executable path and arguments via `sysctl(KERN_PROCARGS2)`, and classifies it as a dev server, an app or a system process. Quitting uses `kill(2)`. Nothing leaves your Mac.

The app can't be sandboxed (it needs to see and signal other processes), so it's distributed outside the Mac App Store.

## Releasing

Push a tag like `v0.1.0`. The Release workflow builds a universal binary and attaches the `.dmg` and `.zip` to a GitHub release.
To sign and notarize, add these repository secrets: `MACOS_CERT_P12` (base64 Developer ID Application certificate), `MACOS_CERT_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` (app-specific password).

## License

MIT
