//
//  main.swift
//  StreamdeckLauncher
//
//  A tiny app whose only job is to run `camview show <liveview>` and exit, so an Elgato
//  Stream Deck button can switch a viewport. The Stream Deck can launch an app but can't
//  pass it arguments, so there is one .app per liveview.
//
//  Rather than compiling one binary per liveview, a single binary is copied to N names and
//  derives the liveview from its own executable name — see Scripts/build-launchers.sh.
//

import Foundation
import os

let log = Logger(subsystem: "com.peterichardson.camview", category: "streamdeck-launcher")

/// The liveview name, from an explicit argument if given, otherwise from this executable's
/// own filename. `camview show` matches liveview names case-insensitively, so an executable
/// named `driveway180` selects the `Driveway180` liveview with no lookup table to keep in
/// sync.
///
/// The argument exists because the derived name is only meaningful for a *copy* the build
/// script made: running the build product directly asks for a liveview called
/// `StreamdeckLauncher`, which no controller has. It makes the binary testable without
/// building a bundle first.
///
/// `lastPathComponent` without `deletingPathExtension()`: the copies have no extension, so
/// stripping one only ever removed a real part of the name — a liveview called `Deck.2`
/// arrived at `camview` as `Deck`.
let target =
    CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent

/// Hardcoded because a Stream Deck-launched app doesn't inherit the user's `$PATH`.
let camview = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent("bin/camview")

let process = Process()
process.executableURL = camview
process.arguments = ["show", target]
process.standardOutput = nil
process.standardError = nil
process.standardInput = nil

do {
    log.log("> \(camview.path, privacy: .public) show \(target, privacy: .public)")
    try process.run()

    // Wait, so the three outcomes are distinguishable in Console.app. Previously the log
    // recorded only that camview had been *started*, which reads identically whether the
    // viewport switched or the liveview name doesn't exist — the case a dead button
    // actually produces.
    //
    // This used to return immediately so the button would "feel instant". It still does:
    // the launcher has no UI and no Dock icon, so waiting delays nothing a user can see,
    // only this process's own exit.
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        log.error(
            "camview show \(target, privacy: .public) failed (exit \(process.terminationStatus, privacy: .public)). Is '\(target, privacy: .public)' a liveview name? Try: camview list liveviews"
        )
    }
} catch {
    // Distinct from the above: camview never started at all, usually because ~/bin/camview
    // isn't installed.
    log.error(
        "Failed to launch \(camview.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
    )
}
