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
- Keep the Stream Deck launcher binaries tiny (~55 KB) and instant to launch

**Non-Goals:**

- Live video streaming or playback — snapshots only
- Cross-platform support; this is macOS-only by design (Keychain, `NSPasteboard`, SwiftUI)
- General-purpose UniFi Protect coverage — the `Protect` package wraps only the
  handful of endpoints camview actually needs
- Being a product. There is no CI, no release process, and no distribution story beyond
  copying a binary to `~/bin`. Tests exist but cover only the config layer.

---

## Architecture

The system is a thin layered stack. At the bottom sit two standalone Swift packages
extracted from this repo over time — `Protect` (UniFi Protect API wrappers and models)
and `SimpleConfig` (credential storage). Above them, `camview` is an ArgumentParser
command tree where each subcommand is a small, self-contained async unit of work.
`camgui` sits beside the CLI as a second front-end over the same packages. The Stream
Deck launchers sit *above* the CLI: they are a separate dependency-free binary that
knows nothing about Protect and simply execs `~/bin/camview show <liveview>`.

Swift Package Manager owns the build. The root `Package.swift` declares three targets —
`CamviewCore` (library), `camview` (executable) and `StreamdeckLauncher` (executable) —
plus a test target. Xcode survives only for `camgui`, which SPM cannot build: a sandboxed
`.app` needs entitlements, an asset catalog and a provisioning profile. Even there the
project is a *generated* artifact — `camgui/project.yml` is the source of truth and
`camgui.xcodeproj` is gitignored, so the build configuration under review is 60 lines of
YAML rather than a pbxproj.

The code shared between the CLI and the GUI is `CamviewCore`, a real library target both
depend on by name. It holds `Configuration` and `configItems`, and deliberately does not
depend on ArgumentParser, so a GUI with no command line doesn't link it.

This replaced an earlier arrangement worth remembering: `camview/commands/config.swift`
was compiled into `camgui` through an Xcode file-system-synchronized-group *membership
exception* — a coupling invisible from the filesystem and visible only in `project.pbxproj`.
When `e3b00e0` made `Configuration.init()` throwing, `camgui` stopped compiling and stayed
broken for eight commits, because nothing in the CLI's own build touches that target.

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
`CamView` (`Sources/camview/camview.swift`) is an empty `AsyncParsableCommand` that exists only
to hold the subcommand list and the long `discussion` help text. The four subcommands
are `list`, `show`, `snapshot`, and `config`. Each one independently constructs a
`Configuration`, builds a `ProtectService`, does its work, and exits — there is no
shared session, service locator, or app state. `list` is generic over `ProtectFetchable`,
so adding a new listable Protect type requires no new printing code.

**`CamviewCore`** (`Sources/CamviewCore/Configuration.swift`)
The bridge between stored credentials and `ProtectService`, and the only code shared by
both products. `configItems` is a dictionary mapping the two known keys to their storage
strategies; the `config` subcommand reads and writes through it, and `Configuration.init()`
reads through it, throwing `ConfigError.unableToLoad` if either the API key or the host is
absent. Neither has a compiled-in default. It depends on `SimpleConfig`, which it uses, and
on `Protect`, which it does not — the latter is re-exported (`Sources/CamviewCore/Protect.swift`)
so that the `Protect` version is pinned in exactly one place instead of once here and once
in `camgui/project.yml`. Still no ArgumentParser, so camgui doesn't inherit a CLI framework
it has no use for.

**`camgui`** (`camgui/`, project generated from `camgui/project.yml`)
A SwiftUI app in early sketch form: `ContentView` loads the camera list in a `.task {}` and
hands it to `CameraList` for display, showing a `ContentUnavailableView` if the load fails
— a missing API key is the expected first-run state, not a crash. It is sandboxed with the
`group.com.peterichardson.camview` app group entitlement, which is precisely why the host
is stored in an app-group suite rather than plain `UserDefaults`: a sandboxed GUI app and
an unsandboxed CLI can both reach it. Whether the *Keychain* half of that story works under
the sandbox is still unverified — see Open Questions.

**Stream Deck launchers** (`Sources/StreamdeckLauncher/`, `Scripts/build-launchers.sh`)
The Stream Deck can launch an app but cannot pass it arguments, so there is one app per
liveview. Rather than compiling a binary per liveview, one binary is built and copied to N
names; it derives its liveview from its own executable name via `CommandLine.arguments[0]`.
Because `camview show` matches liveview names case-insensitively, an executable named
`driveway180` selects the `Driveway180` liveview with no lookup table to drift. The build
script wraps each copy in a `<name>.app/Contents/MacOS` bundle with a generated
`Info.plist` (`LSUIElement`, so nothing appears in the Dock). `main.swift` launches
`~/bin/camview` by absolute path — these apps do not inherit the user's `$PATH` — and logs
failures through `OSLog`, since a Stream Deck button has nowhere else to report them.

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
produced ~3.3 MB bundles; the hand-rolled launchers are ~55 KB and start faster.

**The launcher reads `argv[0]` instead of using a compile-time define.** Originally each
app was a separate `swiftc -D <NAME>` build over a shared `target.swift`, which meant the
liveview list existed twice — once as a `#if` chain, once as a nushell array — and had to
be edited in lockstep (`a10ec04` is exactly that maintenance; the `#if` chain had already
drifted a dead `DOORANDDRIVEWAY` branch the build script never used). Deriving the name at
runtime collapses that to one list in one script. It also happens to be the only approach
SPM can express: SPM rejects targets with overlapping sources, so 15 targets sharing one
source file is not buildable.

**SPM owns the build; Xcode is confined to camgui.** The pbxproj was where problems hid —
an invisible file-membership exception, and schemes that lived in gitignored `xcuserdata/`
so no clone could build the CLI by the documented command. `swift build` needs no scheme,
and camgui's project is generated from a reviewable `project.yml`.

---

## External Dependencies

| Dependency | Purpose |
|------------|---------|
| `Protect` (`PeteRichardson/Protect`, 1.0.x) | UniFi Protect REST wrappers, models, and the `ProtectFetchable` protocol — all network code lives here, not in this repo |
| `SimpleConfig` (`PeteRichardson/SimpleConfig`, 1.0.x) | Keychain + `UserDefaults` config storage behind one `ConfigStorable` protocol, plus `ConfigError` |
| `swift-argument-parser` (Apple, ≥1.5.1) | CLI subcommand tree, argument validation, and generated help |
| XcodeGen | Build-time only, and only for camgui; generates `camgui.xcodeproj` from `project.yml` |

Both first-party packages are pinned to version tags rather than `branch: "main"`. Their
`main` branches have since moved ahead of the revisions camview was actually building
(`Protect` `e5cd3b5f` vs `1.0.0`; `SimpleConfig` `9a9957e1` vs `1.0.0`, with 2.0.0 and
3.0.0 tagged) — under a branch pin, any re-resolve would have silently changed the build.

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

Building:

```sh
swift build -c release            # -> .build/release/camview
swift test
cp .build/release/camview ~/bin/  # the Stream Deck launchers exec this exact path
./Scripts/build-launchers.sh      # regenerates streamdeck extras/apps/
```

camgui is separate, and needs a Mac App Development provisioning profile for
`com.peterichardson.camgui`:

```sh
cd camgui && xcodegen generate
xcodebuild -project camgui.xcodeproj -scheme camgui -configuration Release build
```

Both deployment targets are macOS 15 — the CLI's in `Package.swift`, the GUI's in
`camgui/project.yml`. `Protect` floors both; nothing in camgui needs anything newer than
`ContentUnavailableView` (macOS 14). `swift-tools-version` is 6.2, but every target pins
`.swiftLanguageMode(.v5)`: tools 6.2 defaults to Swift 6 language mode, which surfaces
`ProtectService`'s non-`Sendable` use across `await` and the mutable `static var
configuration`. That migration is deliberately separate from the build-system move.

---

## Open Questions

- [ ] **Can the sandboxed camgui actually read the Keychain?** It builds now, but the
      entitlements grant only an app group — no `keychain-access-groups`. A sandboxed app
      gets its own keychain access group and may not see the generic password the
      unsandboxed CLI wrote under service `com.peterichardson.camview`. Unverified: it has
      never been run signed. If the camera list comes up empty with a config error, this is
      why, and the fix is a shared `keychain-access-groups` entitlement on both sides.
- [ ] `camview config read api-key` prints the key in cleartext (`config.swift`, the
      single-key branch prints the raw value rather than the obfuscating `description`),
      contradicting the README. One line; unrelated to the build.
- [ ] `list.swift` sleeps for two seconds after printing. It sits *after* the closing
      signpost, so it doesn't extend the measured region — it only delays exit. Should be
      removed or gated behind a flag.
- [ ] `show.swift` wraps *every* error in `ConfigError.unknown(error)`, including the
      carefully-worded "Liveview not found" it just threw. The specific message survives
      only because `unknown` prints the underlying error.
- [ ] Three launcher apps — `all`, `familyroom`, `summary` — name liveviews that no longer
      exist in Protect, so those buttons do nothing. Inherited from the original `build.nu`
      list. The Stream Deck README's suggestion to generate the list from
      `camview list liveviews` would prevent it recurring.
- [ ] Should the launcher list be generated at build time? It's down to one list in
      `Scripts/build-launchers.sh`, but it's still hand-maintained and can drift from
      Protect (see above).
- [ ] Protect is reached over plain `http://`. Fine on a trusted LAN, but the API key
      travels in a header in the clear; worth confirming that's an accepted trade-off
      rather than an oversight.
- [ ] Test coverage reaches the pure logic but stops at the network. `CamviewCoreTests`
      pins the config storage identifiers and `Configuration.init()`'s failure paths (via
      its `items:` seam); `CamviewCLITests` covers case-insensitive name matching and
      `list` format dispatch. What remains untested is anything requiring a live
      controller: the commands still construct `ProtectService` directly, so `run()` has
      nowhere to inject a fake.
- [ ] Swift 6 language mode is deferred (`.swiftLanguageMode(.v5)` on every target). The
      known blockers are `ProtectService`'s non-`Sendable` use across `await` and the
      mutable `static var configuration` in `camview.swift`.
- [ ] `camgui`'s direction is undecided: today it lists cameras only. The commit that
      introduced it (`6b3c9f0`) mentions snapshots and possibly video streams as the
      intent.

---

## Document History

| Date | Change |
|------|--------|
| 2026-08-02 | Initial document generated from codebase |
| 2026-08-02 | Rewritten for the Swift Package Manager migration: CamviewCore, generated camgui project, argv[0] launchers |
