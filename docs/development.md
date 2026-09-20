# Development

## Requirements

- Apple Silicon Mac. The published app/plugin binaries target arm64 and macOS 14.4 or later.
- Xcode or Command Line Tools with the Core Audio process tap APIs (14.4+ SDK), clang++, Swift and code signing tools.
- Python 3 for assets, packaging and audit scripts.
- Node.js 22 or later for JavaScript tests. The release was prepared with Node.js 26.
- Optional `@elgato/cli` 1.9.0 for plugin validation and packaging.

If Xcode is selected but its setup is incomplete, finish Xcode setup yourself or use installed Command Line Tools with `DEVELOPER_DIR=/Library/Developer/CommandLineTools` before the commands below.

## Build and test

```sh
./build.command
./test.command
./test-localization.command
./test-memory.command
```

Build products are `Prisma.app`, `io.github.kory-.prisma.sdPlugin/plugin`, the optional `Prisma Auto.streamDeckProfile`, and scratch files inside `.build/`. The app embeds Prisma Tabs. Builds use ad-hoc signatures. Building does not install, run, or replace your existing app or plugin.

`test.command` runs isolated logic and localization audits. UI tests in `test-localization.command` and `test-memory.command` require a logged-in macOS desktop session with WindowServer access; their wrappers fail if the test exits without its completion marker. They construct test views and do not start audio capture.

After building, `python3 Tests/ChromeHostTests.py` checks native messaging framing and origin restrictions. `Tests/ChromeBridgeIntegration.py` is an optional live integration test that emits local messages; do not run it while using Prisma for real playback.

## Package

```sh
npm install --prefix .build/tools @elgato/cli@1.9.0
STREAMDECK_CLI="$PWD/.build/tools/node_modules/.bin/streamdeck" ./package.command
```

The packaging command validates signatures and the Stream Deck manifest, builds release archives from explicit component directories, and produces SHA-256 checksums under `dist/`. It does not upload, install, or notarize anything.

GitHub Actions builds and tests changes on an Apple Silicon macOS runner. Audio permission and physical-device tests remain manual. Publication is a separate maintainer action.

## Structure and identifiers

- `Source/Mixer.mm`: AppKit UI, audio discovery, Core Audio taps and volume processing.
- `Source/Preferences.h`, `Source/Localization.h`: preferences, launch behavior and translations.
- `Source/StreamDeck.swift`: optional Stream Deck plugin.
- `Source/ChromeHost.mm`, `Source/BrowserTabs.h`: local Chrome integration.
- `ChromeExtension/`: Manifest V3 source and translations.
- `io.github.kory-.prisma.sdPlugin/`: public plugin metadata, icons and property inspector.
- `Tests/`: isolated native, JavaScript and integration checks.

The native app ID `local.appmixer.desktop`, local notification names and URL schemes remain stable for existing user preferences. The public Stream Deck ID is `io.github.kory-.prisma`; it is distinct from the old private development ID. The Chrome manifest contains a **public** key to preserve extension identity; no private signing key belongs in this repository or its releases.
