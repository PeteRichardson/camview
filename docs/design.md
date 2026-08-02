# camview — Design Document

*Last updated: 2026-08-02*

---

## Overview

camview is a personal tool for driving a UniFi Protect installation from a Mac:
switching which *liveview* (a grid layout of cameras) is displayed on a *viewport*
(a Protect Viewer device, e.g. a TV running a UniFi Viewer), listing the objects
in the Protect system, and pulling still snapshots from individual cameras. The
primary user is a human at a terminal; the secondary user is an Elgato Stream Deck
button, which launches a tiny generated app that shells out to the CLI.

The repository holds four artifacts: the `camview` CLI, an early-stage `camgui`
SwiftUI app, a set of generated Stream Deck launcher apps, and the glue that binds
them to two external Swift packages the author also maintains.

## Goals and Non-Goals

**Goals:**

- Switch a viewport's liveview in one command, fast enough to feel like a button press
- List cameras, viewports and liveviews in both human and CSV form
- Show a camera snapshot inline in the terminal without writing a temp file
- Store the Protect host and API key once, securely, shared by every artifact here
- Keep the Stream Deck launcher binaries tiny (~51 KB) and instant to launch

**Non-Goals:**

- Live video streaming or playback — snapshots only
- Cross-platform support; this is macOS-only by design (Keychain, `NSPasteboard`, SwiftUI)
- General-purpose UniFi Protect coverage — the `Protect` package wraps only the
  handful of endpoints camview actually needs
- Being a product. There is no test suite, no CI, no release process, and no
  distribution story beyond copying a binary to `~/bin`

---

## Architecture

The system is a thin layered stack. At the bottom sit two standalone Swift packages
extracted from this repo over time — `Protect` (UniFi Protect API wrappers and models)
and `SimpleConfig` (credential storage). Above them, `camview` is an ArgumentParser
command tree where each subcommand is a small, self-contained async unit of work.
`camgui` sits beside the CLI as a second front-end over the same packages. The Stream
Deck launchers sit *above* the CLI: they are separate `swiftc`-compiled binaries that
know nothing about Protect and simply exec `~/bin/camview show <liveview>`.

The single piece of code shared directly between the two Xcode targets is
`camview/commands/config.swift`. Rather than being pushed into a package, it is
compiled into `camgui` via an Xcode file-system-synchronized-group *membership
exception* (`camview.xcodeproj/project.pbxproj:36`). This is why `camgui` also links
ArgumentParser despite having no command line: `Configuration` throws
`ValidationError`.

### Components

**`Protect` package** (external, `github.com/PeteRichardson/Protect`)
Owns everything network-facing. `ProtectService` is constructed with a host and API
key and exposes `cameras()`, `liveviews()`, `viewports()`, `getSnapshot(from:with:)`
and `changeViewportView(on:to:)`. All requests funnel through one private `request(...)`
method that sets the `X-API-KEY` header, checks for a 2xx status, and logs each request
with a short correlation id via `OSLog`. Collection fetches are memoized in per-instance
caches (`cachedCameras` et al.), so a command that needs both viewports and liveviews
pays for each endpoint once. The base URL is built as
`http://<host>/proxy/protect/integration/v1` — plain HTTP, presumably to sidestep the
self-signed certificate a local UniFi controller presents.

**`SimpleConfig` package** (external)
Provides the `ConfigStorable` protocol with two implementations: `ConfigItem`, backed
by a `UserDefaults` suite, and `SecureConfigItem`, backed by the Keychain. It also
supplies the `ConfigError` type that camview reuses for its own failures.

**`camview` CLI**
`CamView` (`camview/camview.swift`) is an empty `AsyncParsableCommand` that exists only
to hold the subcommand list and the long `discussion` help text. The four subcommands
are `list`, `show`, `snapshot`, and `config`. Each one independently constructs a
`Configuration`, builds a `ProtectService`, does its work, and exits — there is no
shared session, service locator, or app state. `list` is generic over `ProtectFetchable`,
so adding a new listable Protect type requires no new printing code.

**`Configuration`** (`camview/commands/config.swift:69`)
The bridge between stored credentials and `ProtectService`. `configItems` is a
dictionary mapping the two known keys to their storage strategies; the `config`
subcommand reads and writes through it, and `Configuration.init()` reads through it,
throwing if the API key is absent and defaulting the host to `unvr.local` if unset.

**`camgui`**
A SwiftUI app in early sketch form: `ContentView` loads the camera list in a `.task {}`
and hands it to `CameraList` for display. It is sandboxed with the
`group.com.peterichardson.camview` app group entitlement, which is precisely why the
host is stored in an app-group suite rather than plain `UserDefaults` — a sandboxed
GUI app and an unsandboxed CLI can both reach it. **This target does not currently
compile** (see Open Questions).

**Stream Deck launchers** (`streamdeck extras/`)
The Stream Deck can launch an app but cannot pass it arguments, so one app per liveview
is generated. `target.swift` is a wall of `#if` branches returning a liveview name; the
`build.nu` nushell script compiles `main.swift` + `target.swift` once per name with a
different `-D` define, strips the binary, and wraps it in a `<name>.app/Contents/MacOS`
bundle with a generated `Info.plist` (`LSUIElement`, so nothing appears in the Dock).
`main.swift` launches `~/bin/camview` by absolute path — these apps do not inherit the
user's `$PATH`.

### Data Flow

`camview show Driveway MyViewport` parses into a `Show` command. `Configuration()`
reads the API key from the Keychain and the host from the app-group defaults, then
`ProtectService` is constructed. `Show` fetches all viewports and resolves
`MyViewport` to an id by case-insensitive name match (falling back to the first
viewport if no name was given), fetches all liveviews and resolves `Driveway` the same
way, and finally issues `PATCH /viewers/<viewportId>` with `{"liveview": "<id>"}`.
Both lookups are name→id translations against list endpoints; the Protect API is
id-oriented, camview is name-oriented, and that translation is the bulk of what the
tool does. If the liveview name doesn't match, `Show` prints the available liveviews
before throwing — the one place an error path doubles as help.

`camview snapshot Backyard` follows the same setup, then asks `ProtectService` for JPEG
bytes and either writes them to `NSPasteboard` (`-c`) or base64-encodes them into an
iTerm2 `OSC 1337;File=inline=1` escape sequence written to stdout.

---

## Key Design Decisions

**Extracting `Protect` and `SimpleConfig` into their own repositories.** The git history
shows both starting life inside this repo and moving out (`83d5eb5`, `22310cf`, `a50e15b`,
`1213563`). The trigger was `camgui`: once two targets needed the same API and config
code, sharing it as a package was cleaner than duplicating it. Both are pinned to
`branch = main` rather than a version tag, which keeps iteration fast at the cost of
non-reproducible builds — a change pushed to `Protect` can break this repo without any
commit here.

**Splitting credentials across two stores.** The API key is a secret and lives in the
Keychain; the host is not and lives in `UserDefaults`. Using an *app group* suite for
the host, rather than the CLI's own defaults domain, is what lets the sandboxed
`camgui` read the same value the CLI wrote.

**`Configuration.init()` throws instead of returning `nil`** (`e3b00e0`). A missing API
key is a real, actionable error with a specific remedy, and the throwing version carries
the "run `camview config write api-key`" message all the way out to the user.

**Case-insensitive name matching everywhere.** Every lookup lowercases both sides. This
is a usability call for a tool typed by hand and invoked from Stream Deck buttons whose
labels don't match Protect's capitalization.

**Caching inside `ProtectService` rather than on disk.** Each CLI invocation is a fresh
process, so the cache only helps within a single command — which is enough, because
`show` needs two endpoints. There is no persistence and no invalidation, which is
correct for a one-shot CLI and a latent problem for a long-lived GUI.

**One generated app per Stream Deck button.** The alternative (Automator) worked but
produced ~3.3 MB bundles; the hand-rolled launchers are ~51 KB and start faster.
The cost is a hardcoded liveview list duplicated in two files (`target.swift` and
`build.nu`) that must be edited together whenever a liveview is added — `a10ec04` is
exactly that maintenance.

---

## External Dependencies

| Dependency | Purpose |
|------------|---------|
| `Protect` (`PeteRichardson/Protect`, branch `main`) | UniFi Protect REST wrappers, models, and the `ProtectFetchable` protocol — all network code lives here, not in this repo |
| `SimpleConfig` (`PeteRichardson/SimpleConfig`, branch `main`) | Keychain + `UserDefaults` config storage behind one `ConfigStorable` protocol, plus `ConfigError` |
| `swift-argument-parser` (Apple, ≥1.5.1) | CLI subcommand tree, argument validation, and generated help |
| nushell | Build-time only; `streamdeck extras/build.nu` generates the launcher apps |

---

## Data Model

The Protect types all conform to `ProtectFetchable`, which composes `Decodable`,
`Comparable`, `Identifiable`, `CustomStringConvertible` and a `CustomCSVConvertible`
protocol, and adds a static `urlSuffix` naming the endpoint. That one requirement is
what makes fetching generic: `fetchAndCache` derives the URL from the type, and
`list(_:format:)` in the CLI prints any conforming type in either summary or CSV form.

The three concrete types are `Camera` (id, name, state, mic settings, video mode, HDR),
`Viewport` (id, name, current `liveview` id, state, stream limit), and `Liveview`
(id, name, `isDefault`, `isGlobal`, owner, layout, and an array of `Slot`s, each
holding camera ids and a cycle mode). Note that a `Viewport` references its liveview
by id, which is why `show` must fetch liveviews to translate a name.

---

## Configuration and Environment

Two values, set once:

```sh
camview config write api-key <32-char-key>     # → Keychain, service com.peterichardson.camview
camview config write protect-host unvr.local   # → UserDefaults suite group.com.peterichardson.camview
camview config read                            # both, api-key obfuscated
```

Both are equally settable with `security` and `defaults`; see the README.

Building: the project has no plain `camview` scheme. The schemes are `camgui`,
`camview -h`, `camview config read`, and `camview list cameras` — run-argument
variants used for debugging in Xcode. Any of the `camview *` schemes builds the CLI:

```sh
xcodebuild -project camview.xcodeproj -scheme "camview -h" -configuration Release build
```

Products land in `Build/Release/`. Building with `-target camview` instead of a scheme
fails to resolve the package modules. `camgui` additionally requires a Mac App
Development provisioning profile for `com.peterichardson.camgui`.

Deployment targets are macOS 15.5 (CLI) and macOS 26.0 (GUI); both targets are set to
Swift language version 5.

---

## Open Questions

- [ ] **`camgui` does not compile.** `ContentView.swift:20` still uses
      `if let config = Configuration()`, but `Configuration.init()` became throwing in
      `e3b00e0`. A type-check against the built modules reports two errors: conditional
      binding on a non-optional, and an unmarked throwing call. It needs
      `guard let config = try? Configuration()` or a `do/catch` that surfaces the error
      in the UI. (`try!` on `protect.cameras()` on line 22 will also crash the app on any
      network failure.)
- [ ] `CLAUDE.md` documents `xcodebuild -scheme camview`, which does not exist. Either
      fix the doc or add a plain `camview` scheme.
- [ ] `list.swift:79` sleeps for two seconds after printing. It appears to be there so
      the `os_signpost` region survives long enough to be sampled in Instruments, but it
      makes every `camview list` feel broken. Should be removed or gated behind a flag.
- [ ] `show.swift` wraps *every* error in `ConfigError.unknown(error)`, including the
      carefully-worded "Liveview not found" it just threw. The specific message survives
      only because `unknown` prints the underlying error.
- [ ] Package dependencies are pinned to `main`, not tags. Worth pinning once the API
      of `Protect` settles.
- [ ] The liveview list is hardcoded in both `target.swift` and `build.nu`. The
      Stream Deck README already suggests generating it from `camview list liveviews`.
- [ ] Protect is reached over plain `http://`. Fine on a trusted LAN, but the API key
      travels in a header in the clear; worth confirming that's an accepted trade-off
      rather than an oversight.
- [ ] There are no tests of any kind, and no obvious seam for them — every command
      constructs its own `ProtectService` directly, so there is nowhere to inject a fake.
- [ ] `camgui`'s direction is undecided: today it lists cameras only. The commit that
      introduced it (`6b3c9f0`) mentions snapshots and possibly video streams as the
      intent.

---

## Document History

| Date | Change |
|------|--------|
| 2026-08-02 | Initial document generated from codebase |
