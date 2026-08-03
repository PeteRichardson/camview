//
//  TerminalCapability.swift
//  camview
//

import Foundation

/// Whether the attached terminal can be expected to draw an inline image.
///
/// `snapshot` emits an OSC-1337 escape sequence, which a terminal that doesn't implement
/// the protocol prints verbatim: half a megabyte of base64, unrecoverable mid-scroll.
///
/// The obvious gate — `TERM_PROGRAM == "iTerm.app"` — would be a net regression, since
/// Warp and WezTerm implement the same protocol. So this asks two independent questions,
/// because neither source is sufficient alone:
///
/// * **`TERM_PROGRAM`** is exact and trustworthy, but only for terminals someone has
///   actually tested and added here. It is the app's *identity*.
/// * **`TERM`** names the terminfo family, which a fork inherits from its parent. A
///   Ghostty-based app reports its own `TERM_PROGRAM` — which no allow-list could ever
///   enumerate — while still setting `TERM=xterm-ghostty`.
///
/// Both lists are conservative, and neither can be complete: this is a heuristic about a
/// capability there is no cheap way to interrogate directly. `snapshot --inline` is the
/// escape hatch for a terminal that works but isn't recognised, and refusing is the
/// default because the cost of a false positive — the base64 dump — is much worse than
/// the cost of a false negative, which is one flag.
enum Terminal {

    /// `TERM_PROGRAM` values known to implement the protocol. These are exactly the three
    /// the README records as tested; adding one is a claim that someone tried it.
    static let inlineImagePrograms: Set<String> = [
        "iTerm.app",      // iTerm2
        "WarpTerminal",   // Warp
        "WezTerm",        // WezTerm
    ]

    /// Terminfo families whose members implement the protocol. Matched against the last
    /// hyphenated component of `TERM`, so `xterm-ghostty` and a bare `wezterm` both hit
    /// and `xterm-256color` does not.
    static let inlineImageTermFamilies: Set<String> = [
        "ghostty",
        "wezterm",
    ]

    /// - Parameters:
    ///   - termProgram: `$TERM_PROGRAM`, or `nil` when unset.
    ///   - term: `$TERM`, or `nil` when unset.
    /// - Returns: `true` only when something positively identifies the terminal as
    ///   capable. Absent or unrecognised information is always `false`.
    static func drawsInlineImages(termProgram: String?, term: String?) -> Bool {
        if let termProgram, inlineImagePrograms.contains(termProgram) {
            return true
        }
        // Substring matching would be the tempting shortcut and would misfire on names
        // that merely embed one of these words. A terminfo name is structured, so the
        // trailing component is the honest thing to compare.
        guard let family = term?.split(separator: "-").last else { return false }
        return inlineImageTermFamilies.contains(family.lowercased())
    }

    /// Reads the current process environment. Split from `drawsInlineImages` so the rule
    /// itself stays a pure function that tests can drive without mutating the environment.
    static func currentDrawsInlineImages(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        drawsInlineImages(termProgram: environment["TERM_PROGRAM"], term: environment["TERM"])
    }
}
