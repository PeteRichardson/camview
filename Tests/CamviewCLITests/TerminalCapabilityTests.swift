//
//  TerminalCapabilityTests.swift
//  CamviewCLITests
//

import Testing

@testable import camview

/// `snapshot` wrote an OSC-1337 escape sequence whenever stdout was a TTY, regardless of
/// whether the terminal implements the protocol. On Terminal.app — the macOS default, and
/// what the README's own example command lands on for a new user — a 384,473-byte JPEG
/// became 512,538 bytes of base64 scrolling past, unrecoverable mid-scroll.
///
/// The obvious gate, `TERM_PROGRAM == "iTerm.app"`, would have been a net regression:
/// Warp and WezTerm implement the same protocol and the README records both as tested.
/// So detection is capability-shaped and has two independent sources, and these pin both.
@Suite("inline image capability detection")
struct TerminalCapabilityTests {

    // MARK: TERM_PROGRAM — the tested-and-known list

    @Test(
        "the three terminals the README records as tested are recognised",
        arguments: ["iTerm.app", "WarpTerminal", "WezTerm"])
    func testedProgramsAreRecognised(program: String) {
        #expect(Terminal.drawsInlineImages(termProgram: program, term: nil))
    }

    @Test("Terminal.app is not recognised — the case that filed #51")
    func terminalAppIsRejected() {
        #expect(!Terminal.drawsInlineImages(termProgram: "Apple_Terminal", term: "xterm-256color"))
    }

    // MARK: TERM — the family fallback

    @Test("a Ghostty-derived terminal is recognised even under a forked name")
    func ghosttyDerivativeIsRecognised() {
        // The case that made a TERM_PROGRAM-only allow-list untenable: a Ghostty-based
        // app reports its own name in TERM_PROGRAM, which no list can enumerate, while
        // TERM still names the family it inherited the capability from.
        #expect(Terminal.drawsInlineImages(termProgram: "supacode", term: "xterm-ghostty"))
    }

    @Test("WezTerm's bare TERM is recognised, not just its TERM_PROGRAM")
    func wezTermByTermAlone() {
        #expect(Terminal.drawsInlineImages(termProgram: nil, term: "wezterm"))
    }

    @Test("the TERM fallback keys on the family, not a substring match")
    func termMatchIsNotSubstring() {
        // `contains` would be the tempting implementation and would misfire: a terminfo
        // name is structured, so the last hyphenated component is the honest place to
        // look. These are the names that must not be swept in.
        #expect(!Terminal.drawsInlineImages(termProgram: nil, term: "xterm-256color"))
        #expect(!Terminal.drawsInlineImages(termProgram: nil, term: "screen"))
        #expect(!Terminal.drawsInlineImages(termProgram: nil, term: "dumb"))
    }

    // MARK: absent information

    @Test("an empty environment is treated as incapable, not as capable")
    func unsetEnvironmentIsIncapable() {
        // The failure mode being prevented is printing half a megabyte of base64. When
        // nothing is known, the safe default is to refuse and say so.
        #expect(!Terminal.drawsInlineImages(termProgram: nil, term: nil))
        #expect(!Terminal.drawsInlineImages(termProgram: "", term: ""))
    }
}

/// The refusal is the whole user-facing deliverable here: #51 notes the old failure "gives
/// no hint that `-c` or a redirect would have worked". An error that just says no would
/// reproduce that.
@Suite("unsupported terminal message")
struct UnsupportedTerminalMessageTests {

    @Test("the refusal names the terminal it refused")
    func namesTheTerminal() {
        let message = String(describing: SnapshotError.unsupportedTerminal(termProgram: "Apple_Terminal"))
        #expect(message.contains("Apple_Terminal"))
    }

    @Test("the refusal names every way forward")
    func namesEveryWayForward() {
        let message = String(describing: SnapshotError.unsupportedTerminal(termProgram: "Apple_Terminal"))
        #expect(message.contains("-c"))          // the clipboard
        #expect(message.contains("> "))          // the redirect
        #expect(message.contains("--inline"))    // the override
    }

    @Test("an unknown terminal still produces a readable sentence")
    func handlesAnUnnamedTerminal() {
        // TERM_PROGRAM is frequently unset — over ssh, in cron, under a bare `sh`.
        let message = String(describing: SnapshotError.unsupportedTerminal(termProgram: nil))
        #expect(!message.contains("nil"))
        #expect(message.contains("--inline"))
    }

    @Test("--inline parses, and is off unless asked for")
    func inlineFlagParses() throws {
        // The message above tells the user to type this. If the spelling drifted from the
        // flag, the advice would send them to a parse error.
        #expect(try Snapshot.parse(["Backyard"]).inline == false)
        #expect(try Snapshot.parse(["Backyard", "--inline"]).inline == true)
    }
}
