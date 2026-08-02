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

/// The liveview name is this executable's own filename. `camview show` matches liveview
/// names case-insensitively, so an executable named `driveway180` selects the `Driveway180`
/// liveview with no lookup table to keep in sync.
let target = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingPathExtension()
    .lastPathComponent

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
    // Deliberately don't wait — the button should feel instant, and there is no UI to
    // report a result to anyway. Failures go to Console.app via the logger above.
} catch {
    log.error(
        "Failed to launch \(camview.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
    )
}
