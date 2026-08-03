# camview — CLAUDE.md

## Project Overview

Two Swift targets that control a **UniFi Protect** system:

- **camview** — macOS CLI tool (uses `ArgumentParser`)
- **camgui** — macOS SwiftUI app

## Repository Layout

Swift Package Manager owns everything it can. Xcode is used only for `camgui`, which SPM
cannot build (sandboxed `.app` with entitlements, asset catalog, provisioning profile).

```
Package.swift            # camview CLI, CamviewCore, StreamdeckLauncher
Sources/
  CamviewCore/           # Configuration + configItems — shared by the CLI and camgui
  camview/               # CLI: camview.swift + commands/
  StreamdeckLauncher/    # One binary, copied to N names (derives liveview from argv[0])
Tests/
  CamviewCoreTests/      # config storage identifiers + Configuration.init
  CamviewCLITests/       # depends on the camview executable target (@testable import camview)
camgui/                  # SwiftUI app + its own Xcode project
Scripts/
  build-launchers.sh     # builds the Stream Deck .app bundles
streamdeck extras/       # Info.plist template, icons, generated apps/ (gitignored)
```

`CamviewCore` exists so the CLI and the GUI share config code through a real library
target rather than an invisible Xcode file-membership exception. It deliberately does
**not** depend on ArgumentParser — a GUI with no command line shouldn't link it.

## Key Dependencies (Swift Packages)

| Package | Location | Purpose |
|---------|----------|---------|
| `Protect` | `https://github.com/PeteRichardson/Protect` | UniFi Protect API wrappers |
| `SimpleConfig` | `https://github.com/PeteRichardson/SimpleConfig` | Config storage: `ConfigItem` (UserDefaults), `SecureConfigItem` (Keychain) |
| `ArgumentParser` | Apple open source | CLI subcommand parsing |

Pinned to version tags, not `branch: "main"` — both first-party packages have moved ahead
of what camview builds against, so a branch pin would change behaviour on any re-resolve.

## Build

```sh
swift build                          # debug -> .build/debug/camview
swift build -c release               # release -> .build/release/camview
swift test
swift run camview list cameras       # run without installing
```

Install the CLI where the Stream Deck launchers expect it:

```sh
swift build -c release && cp .build/release/camview ~/bin/
```

Stream Deck apps (regenerates `streamdeck extras/apps/`):

```sh
./Scripts/build-launchers.sh
```

camgui:

```sh
xcodebuild -project camgui/camgui.xcodeproj -scheme camgui -configuration Release build
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

- camview CLI / CamviewCore: macOS 15 (`Package.swift` — floor set by the `Protect` dependency)
- camgui app: macOS 26.0 (Xcode build setting)

## Swift Version

`swift-tools-version: 6.2`, but every target pins `.swiftLanguageMode(.v5)`. Tools 6.2
would otherwise default to Swift 6 language mode, which surfaces `ProtectService`'s
non-`Sendable` use across `await` and the mutable `static var configuration`. Migrating
those is tracked separately — don't flip the mode without doing that work.

## Coding Conventions

- Async/await throughout (`AsyncParsableCommand`, `URLSession`)
- `OSLog` for network logging
- SwiftUI + `@State` / `.task {}` for async data loading in camgui
- Names are case-insensitive when matching cameras/viewports/liveviews
