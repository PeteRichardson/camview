---
git_sha: 0d21834
generated_at: 2026-08-02
scope: whole repo
run: 2 (repeat-run; supersedes the 63b7ba4 run)
---

# camview — Project Review

*Repeat run at `0d21834`. 637 lines of Swift plus 185 lines of build definitions, across 12 source files.*

**What changed since the last run (`63b7ba4`):** the project migrated from a two-target
Xcode project to Swift Package Manager over 6 commits. 12 findings are now `RESOLVED`,
1 is downgraded from its original claim, and 8 are `NEW` — most of them introduced *by*
the migration, which is the point of re-running.

Finding IDs are stable across runs. New findings start at F36, continuing from the
git-history scan (max prior ID: F35).

---

## Executive summary

1. **The migration did what it was supposed to.** 12 findings resolved, including all four
   that traced back to the invisible pbxproj file-membership exception (F1, F6, F22, F23).
   The build graph is now 56 lines of `Package.swift` plus a 63-line `project.yml`.
2. **F2 is still open and still Critical.** `camview config read api-key` prints the key in
   cleartext (`config.swift:40`). It's one line, unrelated to the build, and has now
   survived two reviews and a full refactor of the file it lives in.
3. **The launcher rework fixed a duplication problem and left a correctness one.** Three
   apps — `all`, `familyroom`, `summary` — name liveviews that don't exist in Protect (F37).
   They've been dead buttons for some time; restoring the logging (F20) is what made them
   visible.
4. **The generated `.app` bundles fail code-signature verification** (F39). They run today
   because they're locally built and unquarantined, but `codesign -v` rejects every one.
   One line in the build script fixes it.
5. **`camgui/project.yml` re-introduces the exact duplication F21 just removed** (F40): the
   `Protect` version is pinned in both `Package.swift:21` and `project.yml:27`, and camgui
   resolves its own separate dependency copy, so the two can silently diverge.
6. **`project.yml` lists camgui's sources explicitly** (F41), so a new `.swift` file added
   to `camgui/` is silently not compiled. That is the same *class* of trap as the
   membership exception the migration removed — invisible-from-the-filesystem build config.
7. **`streamdeck extras/README.md` documents a build system that no longer exists** (F36) —
   `build.nu`, nushell, and the per-app `-D` define approach, all deleted.
8. **F4 (tests) is downgraded, not resolved.** A test target now exists with 4 passing
   tests, but they cover only config storage identifiers. The name→id translation that is
   most of what camview does remains untested, and there's still no seam to inject a fake
   `ProtectService`.
9. **The CLI's argument surface is untouched by the migration** and remains the largest
   cluster of open findings: F10–F19, F24, F25 — stdout-only diagnostics, free-string
   arguments, silent format fallback, no TTY check, no input validation.
10. **Deliberately deferred and now explicit:** Swift 6 language mode is pinned to `.v5` in
    four places (F26) with the two known blockers named in `CLAUDE.md`. That's an
    improvement over the previous silent default, but the debt is unchanged.

No new categories introduced; all 43 findings fit the existing vocabulary.

---

## Architectural mental model

camview is still a name→id translation layer over the UniFi Protect REST API — the Protect
API is id-oriented, humans are name-oriented, and nearly every command fetches a collection,
matches a lowercased name, and issues a request against the resulting id. What changed is
everything around that core.

Swift Package Manager now owns the build. `Package.swift` declares four targets:
`CamviewCore` (the shared `Configuration`/`configItems` library), `camview` (the
ArgumentParser command tree), `StreamdeckLauncher` (a dependency-free launcher), and
`CamviewCoreTests`. Xcode survives only for `camgui`, which SPM cannot build — a sandboxed
`.app` needs entitlements, an asset catalog and a provisioning profile — and even there the
project is *generated* from `camgui/project.yml` and gitignored.

The important structural change is that the CLI and the GUI now share code through a
declared library product rather than an Xcode file-membership exception. That exception was
the root cause of the longest-lived defect in this repo: camgui stopped compiling at
`e3b00e0` and stayed broken for eight commits because nothing in the CLI's build touched
the GUI target. The new arrangement makes the dependency visible in source.

The Stream Deck launchers changed shape too. Previously 15 binaries were compiled from one
source file via `-D` defines, with the liveview list duplicated in a `#if` chain and a
nushell array. Now one binary is built and copied to 15 names, deriving its liveview from
`CommandLine.arguments[0]`. This was partly forced — SPM rejects targets with overlapping
sources, so the old shape isn't expressible — and it collapsed the list to one place.

Where debt now concentrates has shifted. The old hotspot was the pbxproj; that file is
gone. The new hotspots are the two hand-maintained lists that no longer have a second copy
to disagree with, but still have *reality* to disagree with: `Scripts/build-launchers.sh`'s
`VIEWS` array (which Protect has already outgrown) and `camgui/project.yml`'s explicit
`sources` list. Both are build config that fails silently rather than loudly.

---

## Findings

`RESOLVED` = fixed since the last run. `NEW` = first seen this run. Untagged = carried over,
still present, re-verified against current line numbers.

| ID | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|----------|-----------|----------|--------|-------------|----------------|
| F2 | Security hygiene / Documentation drift | `Sources/camview/commands/config.swift:40` | Critical | S | `print(value.description)` on the unwrapped `String`, so `camview config read api-key` emits the raw key. The no-argument path prints the `ConfigStorable` and obfuscates. `README.md:35` promises obfuscation. Survived a full rewrite of this file. | Print `item.description` in both branches; add `--reveal` if cleartext is ever wanted. |
| F3 | Performance & resource hygiene / UX & CLI ergonomics | `Sources/camview/commands/list.swift:80` | High | S | `try await Task.sleep(nanoseconds: 2_000_000_000)` still present, still *after* the closing signpost — so it instruments nothing and only delays exit by 2s on every list. | Delete the line. |
| F4 | Test debt | `Tests/CamviewCoreTests/ConfigurationTests.swift` | High | L | **Downgraded, not resolved.** A test target now exists (4 passing tests) covering config storage identifiers. Still untested: case-insensitive name→id resolution, `list` format dispatch, snapshot output selection. Commands construct `ProtectService` directly, so there is still no injection seam. No CI. | Introduce a protocol seam for `ProtectService` and test the name-matching logic, which is the bulk of the CLI's behaviour. |
| F7 | Error handling & observability | `Sources/camview/commands/show.swift:59-61` | High | S | `catch { throw ConfigError.unknown(error) }` still wraps every error, including the `ConfigError.unableToLoad` thrown three lines above and `Configuration`'s own guidance. | Remove the blanket `do/catch`; the throws propagate correctly unaided. |
| F37 | Data integrity & robustness / UX & CLI ergonomics | `Scripts/build-launchers.sh:25,32,38` | High | S | **NEW.** Three launcher apps — `all`, `familyroom`, `summary` — name liveviews that no longer exist in Protect (verified against `camview list liveviews`: 12 liveviews, all others matched). Pressing those Stream Deck buttons does nothing. Inherited from the original `build.nu` list; invisible until F20 restored logging. | Delete the three entries, or generate `VIEWS` from `camview list liveviews` as the Stream Deck README has suggested since the beginning. |
| F39 | Dependency & config debt | `Scripts/build-launchers.sh:55-58` | Medium | S | **NEW.** Every generated `.app` fails `codesign -v`: *"code has no resources but signature indicates they must be present"*. The bundle inherits the executable's linker-signed signature, which doesn't describe a bundle. They run today only because they're locally built and unquarantined. Confirmed the executable itself is fine — stripping is not the cause; the bundle is never signed as a bundle. | Add `codesign -s - --force "$app"` after writing `Info.plist`. Verified this makes `codesign -v` pass and the app still runs. |
| F40 | Consistency rot / Dependency & config debt | `camgui/project.yml:26-27`; `Package.swift:21` | Medium | S | **NEW.** The `Protect` version is pinned in two places, and camgui resolves its own dependency copy under `camgui/Build/.../SourcePackages`. Nothing enforces agreement, so camgui and the CLI can build against different `Protect` versions. This is the same duplicated-list failure mode F21 just eliminated. | Have camgui depend on `Protect` transitively through the `CamviewCore` product (re-export it), or document the pair as a unit that must be edited together. |
| F41 | Architectural decay / Dependency & config debt | `camgui/project.yml:36-40` | Medium | S | **NEW.** camgui's sources are listed file-by-file. A new `.swift` added to `camgui/` is silently not compiled — no error, just absent behaviour. Chosen deliberately (globbing `.` swept the `Build/` directory's SPM checkouts into app Resources), but the failure mode is invisible build config, the same class of trap as the pbxproj membership exception this migration removed. | Glob with an exclusion instead: `sources: [{path: ., excludes: [Build, project.yml, camgui.xcodeproj, camgui.entitlements]}]`. |
| F36 | Documentation drift | `streamdeck extras/README.md:12,14,17,18` | Medium | S | **NEW.** Documents a build system that no longer exists: `build.nu`, nushell, the per-app `-D` define, and the hardcoded list. The file it tells you to edit was deleted in `f6b1af8`. | Rewrite for `Scripts/build-launchers.sh` and the `argv[0]` scheme. Its standing suggestion — generate the list from `camview list liveviews` — is now the fix for F37 and worth keeping. |
| F38 | Data integrity & robustness | `Scripts/build-launchers.sh:51-61` | Medium | S | **NEW.** The script only creates and overwrites; it never removes. Deleting a name from `VIEWS` leaves its `.app` in `streamdeck extras/apps/` forever, so a "removed" button keeps working (or keeps failing). Directly blocks the clean fix for F37. | `rm -rf "$APPS_DIR"` before the loop, or prune bundles whose name isn't in `VIEWS`. |
| F42 | Data integrity & robustness | `Sources/StreamdeckLauncher/main.swift:21-23` | Medium | S | **NEW.** The liveview comes from `argv[0]` with no validation. Running the build product directly (`.build/release/StreamdeckLauncher`) requests a liveview named `StreamdeckLauncher`; `deletingPathExtension()` also truncates any name containing a dot. Failure is silent apart from the log line. | Accept an optional argument override, and log distinctly when `camview` exits non-zero so a bad name is distinguishable from a missing binary. |
| F10 | Error handling & observability / UX & CLI ergonomics | `Sources/camview/commands/show.swift:52` | Medium | S | 7 `print()` calls across the commands, 0 uses of stderr. Piping `camview list -f csv` to a file captures error text as data. | Route diagnostics through `FileHandle.standardError`. |
| F11 | UX & CLI ergonomics / IDIOM | `Sources/camview/commands/list.swift:55,69-78` | Medium | S | `object` is still a free `String` hand-validated by a `switch`. | `enum ListObject: String, ExpressibleByArgument`. |
| F12 | UX & CLI ergonomics | `Sources/camview/commands/list.swift:35-41,58` | Medium | S | `-f json` still silently produces summary output with exit 0. | Same `ExpressibleByArgument` fix as F11. |
| F13 | Documentation drift | `Sources/camview/camview.swift:16-93` | Medium | M | The 85-line `discussion` still duplicates the README and still says "the first viewport returned by the **list liveviews** command" (should be `list viewports`). Still omits the `viewport` argument `show.swift:22` accepts. | Cut to a short orientation block plus a README pointer. |
| F14 | Documentation drift / UX & CLI ergonomics | `Sources/camview/commands/snapshot.swift:23-24` | Medium | S | `--high-quality` still documented nowhere (0 mentions in README or help). | Document it, or drop it. |
| F15 | UX & CLI ergonomics | `Sources/camview/commands/show.swift:19-23` | Medium | S | `camview show MyViewport` still silently reads as a liveview name; `README.md:56-58` still documents the trap rather than fixing it. | `camview show [liveview] [--viewport <name>]`. |
| F16 | UX & CLI ergonomics / Dependency & config debt | `Sources/camview/commands/snapshot.swift:21`; `Sources/CamviewCore/Configuration.swift:31` | Medium | S | Personal defaults still compiled in: `camera = "FrontDoor"`, `defaultHost = "unvr.local"`. The host default now also masks a failed App Group read, since the fallback is identical to the stored value. | Make `camera` required. Distinguish "host unset" from "host read failed". |
| F17 | Data integrity & robustness | `Sources/camview/commands/snapshot.swift:52-56` | Medium | S | `if let image = NSImage(data:)` with no `else` — decode failure copies nothing, prints nothing, exits 0. | Throw on decode failure. |
| F18 | Data integrity & robustness / UX & CLI ergonomics | `Sources/camview/commands/snapshot.swift:29-43` | Medium | S | Still 0 `isatty` checks; `camview snapshot X > out.jpg` writes escape-wrapped base64. | Check `isatty(STDOUT_FILENO)`; write raw bytes when not a TTY. |
| F19 | Architectural decay | `Sources/camview/commands/list.swift:14-22` | Medium | S | `FileNotFoundError` still declared, still unreferenced — now survived a file move that touched every line's path. | Delete. |
| F24 | Data integrity & robustness | `Sources/camview/commands/config.swift:14-27` | Medium | S | `config write` still accepts any value for any key — no length check on the 32-char API key, no non-empty check on the host. | Validate in `Write.run()` before storing. |
| F25 | Error handling & observability | `Sources/camview/commands/list.swift:62-79` | Medium | S | Still 0 `defer` — the `.begin` signpost leaks whenever an invalid object type throws. | `defer { os_signpost(.end, …) }` after the begin. |
| F26 | Type & contract debt | `Package.swift:35,45,52,54` | Medium | M | Swift 6 language mode still off, now explicitly via `.swiftLanguageMode(.v5)` on all four targets. Blockers are documented in `CLAUDE.md`: `ProtectService` non-`Sendable` across `await`, and F28's mutable static. Deferring is defensible; the debt is unchanged. | Migrate while the surface is 637 lines, or enable `SWIFT_STRICT_CONCURRENCY=complete` to size the work. |
| F27 | Dependency & config debt | `camgui/project.yml:15` | Medium | S | camgui still requires macOS 26.0 while the CLI targets 15; nothing in camgui's 84 lines obviously needs it. Now a one-line change in `project.yml` rather than a pbxproj edit. | Lower to match unless a specific API requires otherwise. |
| F28 | IDIOM | `Sources/camview/camview.swift:13` | Medium | S | `static var configuration` where all four subcommands use `static let`. Also a Swift 6 blocker (F26). Maintenance severity alone: Low. | `static let`. |
| F30 | IDIOM | `Sources/camview/commands/list.swift:25` | Medium | S | **Partially resolved.** `Configuration`'s properties are now `let` (rewritten in `CamviewCore`). `var desc: String` is still hoisted above the loop C-style. | Move `desc` into the loop or collapse the switch to a ternary. |
| F43 | Consistency rot | `Scripts/`, `streamdeck extras/`, `Sources/StreamdeckLauncher/` | Low | S | **NEW.** One feature now spans three directories: source in `Sources/StreamdeckLauncher/`, build script in `Scripts/`, template and icons in `streamdeck extras/`, output in `streamdeck extras/apps/`. Defensible (source vs. resources vs. tooling) but the `streamdeck extras/` name no longer describes what's left in it. | Fold the template and icons under `Sources/StreamdeckLauncher/Resources/`, or rename the folder to reflect that it's now assets + generated output. |
| F31 | Consistency rot | `camgui/CameraListView.swift:2,11` | Low | S | File, header comment, and type still disagree: `CameraListView.swift` / `CameraList.swift` / `struct CameraList`. | Settle on `CameraListView`. |
| F32 | Documentation drift | `Sources/camview/commands/snapshot.swift:2`; `Sources/camview/camview.swift:2` | Low | S | Copy-paste headers survived the move: `snapshot.swift` says "Show.swift", `camview.swift` says "main.swift". | Fix or delete. |
| F34 | Documentation drift | repo root | Low | S | Still no LICENSE on a public repo whose README invites reuse of the Stream Deck code. | Add one. |
| F1 | Correctness & memory safety | `camgui/ContentView.swift` | Critical | S | **RESOLVED** in `3820c94`. camgui compiles; verified BUILD SUCCEEDED and the app runs with the camera list populating. | — |
| F5 | Dependency & config debt | `camgui/camgui.entitlements` | High | M | **RESOLVED** in `0d21834`, but the diagnosis in this finding was wrong. Keychain access works fine under the sandbox. The real blocker was a missing `com.apple.security.network.client`, surfacing as NSURLError -1003 with "Resolved 0 endpoints" — which reads as a DNS problem and isn't. | — |
| F6 | Correctness & memory safety | `camgui/ContentView.swift` | High | S | **RESOLVED** in `3820c94`. `try!` replaced by `do/catch` rendering a `ContentUnavailableView`. | — |
| F8 | Dependency & config debt / Documentation drift | `CLAUDE.md` | High | S | **RESOLVED** in `749c5e2`/`3a147f8`. `swift build` needs no scheme; `camview.xcodeproj` deleted and docs corrected. | — |
| F9 | Dependency & config debt | `Package.swift:21-22` | High | S | **RESOLVED** in `749c5e2`. Pinned to tags. More urgent than stated: both packages' `main` had already moved past the built revisions, so migrating under a branch pin would have silently swapped versions. | — |
| F20 | Error handling & observability | `Sources/StreamdeckLauncher/main.swift:38,43` | Medium | S | **RESOLVED** in `f6b1af8`. `os.Logger` restored on both paths — which immediately exposed F37. | — |
| F21 | Consistency rot | `Scripts/build-launchers.sh` | Medium | M | **RESOLVED** in `f6b1af8`. One list, in one file. The predicted drift had already occurred (`DOORANDDRIVEWAY` branch never built). | — |
| F22 | Architectural decay | `Sources/CamviewCore/Configuration.swift` | Medium | M | **RESOLVED** in `749c5e2`. `CamviewCore` is a declared library product; the membership exception is gone with the pbxproj. | — |
| F23 | Consistency rot | `Sources/CamviewCore/Configuration.swift:38` | Medium | S | **RESOLVED** in `749c5e2`. Throws `ConfigError.unableToLoad`; camgui no longer links ArgumentParser. CLI error output verified byte-identical. | — |
| F29 | IDIOM | `camgui/ContentView.swift:17` | Medium | S | **RESOLVED** in `3820c94`. `NavigationSplitView`, with `.navigationTitle` on the content where it renders. | — |
| F33 | Dependency & config debt | `.gitignore` | Low | S | **RESOLVED** in `098e889`. | — |
| F35 | Documentation drift | `CLAUDE.md:38` | Low | S | **RESOLVED** in `3a147f8`. | — |

---

## Top 5 — if you fix nothing else, fix these

### 1. F2 — stop printing the API key (Critical, one line, twice deferred)

```swift
// Sources/camview/commands/config.swift:38-42
if let item = configItems[key] {
    print(item.description)          // was: print(value.description) on the raw String
} else {
    print("No value set for \(key)")
}
```

`SecureConfigItem.description` already renders `abc123....................xyz789`. This has
now outlived two reviews and a rewrite of the file it lives in.

### 2. F37 + F38 — the three dead Stream Deck buttons

These are one job: F38 blocks F37's clean fix, because deleting names from `VIEWS` leaves
their bundles behind.

```diff
+rm -rf "$APPS_DIR"          # stale bundles otherwise outlive their VIEWS entry
 mkdir -p "$APPS_DIR"
```

Then drop `all`, `familyroom`, `summary`. Better still, generate the list — which the Stream
Deck README proposed before any of this refactoring:

```bash
mapfile -t VIEWS < <(camview list liveviews -f csv | tail -n +2 | cut -d, -f1 | tr 'A-Z' 'a-z')
```

That makes drift structurally impossible rather than a comment to re-check.

### 3. F39 — sign the bundles

```diff
     sed "s/REPLACEME/$view/g" "$TEMPLATE" > "$app/Contents/Info.plist"
+    codesign -s - --force "$app"
```

Verified: `codesign -v` passes afterwards and the app still launches. Without it every
bundle fails verification, which will bite the first time one is copied to another Mac or
macOS tightens enforcement.

### 4. F41 — stop listing camgui's sources by hand

```yaml
sources:
  - path: .
    excludes: [Build, project.yml, camgui.xcodeproj, camgui.entitlements]
```

The explicit list was a workaround for the glob sweeping `Build/` into app Resources;
excluding `Build` addresses that directly. As written, adding a file to `camgui/` fails
silently — the same invisible-build-config trap the migration was meant to end.

### 5. F3 — delete the two-second sleep

```diff
  os_signpost(.end, log: log, name: "List", "%{public}s", "Finished")
- try await Task.sleep(nanoseconds: 2_000_000_000)
```

It sits after the closing signpost, so it measures nothing. It is the single most
user-visible defect in a tool whose entire value is feeling instant.

---

## Quick wins

Low effort, Medium or higher severity:

- [ ] **F2** — print `item.description` (Critical, one line)
- [ ] **F3** — delete `Task.sleep` in `list.swift:80`
- [ ] **F39** — `codesign -s - --force "$app"` in the build script
- [ ] **F38** — `rm -rf "$APPS_DIR"` before the loop
- [ ] **F37** — drop the three dead liveview names
- [ ] **F19** — delete unused `FileNotFoundError`
- [ ] **F7** — remove the blanket `do/catch` in `show.swift`
- [ ] **F25** — `defer` the closing signpost
- [ ] **F28** — `static var` → `static let`
- [ ] **F40** — collapse the duplicated `Protect` pin
- [ ] **F41** — glob camgui sources with an exclusion
- [ ] **F14** — document `--high-quality`
- [ ] **F27** — lower camgui's deployment target
- [ ] **F32** — fix the two stale header comments
- [ ] **F34** — add a LICENSE

---

## Things that look bad but are actually fine

**`camgui.xcodeproj` isn't committed.** A generated project that only exists after running
`xcodegen generate` looks like a broken checkout. It's the right call: `project.yml` is
reviewable, a pbxproj isn't, and this repo's worst historical bug lived in a pbxproj detail
nobody could see. The regeneration command is in `.gitignore` next to the rule.

**Sources are split across `Sources/`, `camgui/`, and `streamdeck extras/`.** This reads as
disorganisation but reflects three genuinely different build systems — SPM, Xcode, and a
copy script. Only the naming is stale, which is F43 (Low).

**`Package.swift` pins `.swiftLanguageMode(.v5)` on every target.** Pinning to an older
language mode usually signals avoidance. Here it's deliberate and documented, and it kept a
concurrency migration out of a build-system migration. Tracked as F26 rather than hidden.

**`StreamdeckLauncher` is exposed as a package product.** It doesn't need to be — nothing
external consumes it. But it costs nothing and makes `swift build --product` work, which
the build script uses.

**`ProtectService`'s caches are never invalidated.** Still correct for a one-shot CLI: each
invocation is a fresh process and the cache exists so `show` doesn't fetch twice. It will
become a real bug when camgui grows a refresh button — not before.

**The three dead launcher apps aren't a regression from the `argv[0]` rework.** They were
equally dead under `build.nu`; the new logging is what surfaced them. Flagged as F37 on
merit, not blamed on the refactor.

**`camview show` prints diagnostics to stdout before failing (F10) yet still exits 1.** The
exit code is correct, and I verified it byte-identical to the pre-migration binary — the
stream choice is the bug, not the exit status.

---

## Open questions for the maintainer

- **Are `all`, `familyroom` and `summary` liveviews you deleted, or Stream Deck buttons you
  still want?** F37 assumes the former. If the latter, the fix is in Protect, not here.
- **Is plain `http://` to the controller deliberate?** Unchanged from the last run and still
  unanswered — the API key travels in a header in the clear. `Protect.swift:51`.
- **Should camgui share the CLI's dependency resolution?** F40's cleanest fix is re-exporting
  `Protect` from `CamviewCore`, which couples the two more tightly than you may want.
- **Is `unvr.local` a UniFi convention or your hostname?** It now matters more: it's both the
  stored value and the fallback, so a failed App Group read is indistinguishable from success
  (F16).
- **Do you want `camview snapshot > file.jpg` to work?** F18's TTY check would enable it as a
  side effect. Deliberate scope limit, or not built yet?
- **`swiftlint` and `periphery` are still not installed**, so idiom and dead-code findings
  remain hand-derived. `swift build` is warning-free, which is genuine but weaker evidence.

---

## Document History

| Date | Change |
|------|--------|
| 2026-08-02 | Initial document generated from codebase (`63b7ba4`) |
| 2026-08-02 | Rewritten for the SPM migration (superseded) |
| 2026-08-02 | Repeat run at `0d21834`: 12 findings RESOLVED, F4 downgraded, F36–F43 NEW |
