# camview — CLAUDE.md

## Project Overview

Two Swift targets that control a **UniFi Protect** system:

- **camview** — macOS CLI tool (uses `ArgumentParser`)
- **camgui** — macOS SwiftUI app

## Repository Layout

```
camview/            # CLI source (main.swift + commands/)
  commands/         # config.swift, list.swift, show.swift, snapshot.swift
camgui/             # SwiftUI app source
camview.xcodeproj/  # Xcode project (both targets)
Build/              # Local build output (not committed)
streamdeck extras/  # Helper scripts for Elgato Stream Deck integration
```

## Key Dependencies (Swift Packages)

| Package | Location | Purpose |
|---------|----------|---------|
| `Protect` | `https://github.com/PeteRichardson/Protect` | UniFi Protect API wrappers |
| `SimpleConfig` | (separate package) | Config storage: `ConfigItem` (UserDefaults), `SecureConfigItem` (Keychain) |
| `ArgumentParser` | Apple open source | CLI subcommand parsing |

## Build

Use Xcode or `xcodebuild`. Build products land in `Build/Release/`.

```sh
xcodebuild -project camview.xcodeproj -scheme camview -configuration Release
```

## Configuration Storage

- **API Key** → macOS Keychain, service `com.peterichardson.camview`, account `api-key`
- **Protect Host** → UserDefaults App Group `group.com.peterichardson.camview`, key `protect-host`

Set via:
```sh
camview config write api-key <32-char-key>
camview config write protect-host <host-or-ip>
```

## Deployment Targets

- camview CLI: macOS 15.5
- camgui app: macOS 26.0

## Swift Version

Swift 5.0 (Xcode project setting)

## Coding Conventions

- Async/await throughout (`AsyncParsableCommand`, `URLSession`)
- `OSLog` for network logging
- SwiftUI + `@State` / `.task {}` for async data loading in camgui
- Names are case-insensitive when matching cameras/viewports/liveviews
