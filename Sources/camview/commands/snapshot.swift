//
//  Show.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser
import AppKit
import CamviewCore
import Protect


/// Snapshot-specific failures. `ConfigError` is the only error type otherwise in reach
/// here, and it comes from SimpleConfig and renders as "Unable to load config: …" — which
/// would describe a decode or clipboard failure wrongly.
///
/// Internal rather than `private` so the tests can assert on `unsupportedTerminal`'s text.
/// That message is the deliverable of #51, not an implementation detail of it: the failure
/// it replaces was bad precisely because it told the user nothing about what to do next.
enum SnapshotError: Error, CustomStringConvertible {
    case undecodableImage(bytes: Int)
    case clipboardWriteFailed
    case unsupportedTerminal(termProgram: String?)

    var description: String {
        switch self {
        case .undecodableImage(let bytes):
            return "Could not decode the \(bytes) bytes returned by Protect as an image"
        case .clipboardWriteFailed:
            return "The system refused the image; the clipboard is unchanged"
        case .unsupportedTerminal(let termProgram):
            // Naming all three ways out is the point. The old behaviour printed ~500 KB
            // of base64 and left the user with no indication that `-c` would have worked.
            let name = termProgram.map { "\($0)" } ?? "This terminal"
            return """
                \(name) is not known to draw images inline, and printing the escape \
                sequence anyway would dump around half a megabyte of base64 to your \
                screen. Try one of:
                  camview snapshot -c <camera>             copy it to the clipboard
                  camview snapshot <camera> > shot.jpg     write a JPEG file
                  camview snapshot --inline <camera>       draw anyway, if you know \
                this terminal supports it
                """
        }
    }
}

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a snapshot of a camera's current view",
        discussion: """

Where the image goes depends on how you invoke it:

  camview snapshot Backyard                drawn inline in the terminal
  camview snapshot Backyard > shot.jpg     raw JPEG bytes, a usable file
  camview snapshot -c Backyard             copied to the clipboard

Inline drawing uses the iTerm inline-image protocol, not Kitty's, and only some
terminals implement it. iTerm2, Warp and WezTerm are recognised by name; Ghostty
and WezTerm are also recognised from TERM, which is what catches their forks.

Anywhere else camview refuses and tells you how to proceed, rather than printing
half a megabyte of base64 at you. Pass --inline to override that if you know
your terminal can draw it.

This captures a single still frame, not a video stream.
""",
    )
    
    /// Required: there is no camera name that is right for everyone, and the previous
    /// default was simply one of the author's own cameras. Omitting it now prints usage
    /// rather than failing against a camera the user has never heard of.
    @Argument(help: "Name of camera to snapshot")
    var camera: String
    
    @Flag(name: [.customShort("c"), .customLong("clipboard")], help: "copy to clipboard instead of terminal")
    var sendToClipboard: Bool = false

    /// Only relaxes the capability check; it does not override the `isatty` branch, so a
    /// redirect still writes raw JPEG bytes and cannot be turned into an escape sequence.
    @Flag(help: "draw inline even if this terminal isn't recognised as supporting it")
    var inline: Bool = false
    
    func showImageInITerm2(data: Data) {
        // Base64-encode the image
        let base64 = data.base64EncodedString()
        
        // iTerm2 escape sequence format for inline images
        let esc = "\u{1b}" // Escape character
        let osc = "]"
        let st = "\\"
        
        let header = "\(esc)\(osc)1337;File=inline=1;width=auto;height=auto;preserveAspectRatio=1:"
        let footer = "\(esc)\(st)"

        // Print the sequence to the terminal
        print("\(header)\(base64)\(footer)")
    }
    
    /// Where the fetched bytes are headed, decided before anything is fetched.
    private enum Destination {
        case clipboard
        case inlineImage
        case rawBytes
    }

    /// Resolved up front so an unusable destination fails before the network call rather
    /// than after it. Refusing to draw is a property of the environment, not of the image,
    /// so there is no reason to make the user wait for a snapshot that gets thrown away.
    private func resolveDestination(environment: [String: String]) throws -> Destination {
        if sendToClipboard { return .clipboard }
        guard isatty(STDOUT_FILENO) == 1 else {
            // Redirected or piped. The escape sequence is for a terminal to interpret, so
            // emitting it here would corrupt the file: `camview snapshot Backyard > out.jpg`
            // produced an escape-wrapped base64 blob rather than a JPEG.
            return .rawBytes
        }
        // Only some terminals implement OSC-1337. The rest print it, which turned a
        // 384 KB JPEG into 512 KB of base64 scrolling past with no way to stop it — and
        // Terminal.app, the macOS default, is one of them, so this is what the README's
        // own example command did on a stock install.
        guard inline || Terminal.currentDrawsInlineImages(environment: environment) else {
            throw SnapshotError.unsupportedTerminal(termProgram: environment["TERM_PROGRAM"])
        }
        return .inlineImage
    }

    func run() async throws {
        let config = try Configuration()
        // After the config check, so a user who hasn't set an api-key is told that first —
        // it's the problem they have to fix either way.
        let destination = try resolveDestination(environment: ProcessInfo.processInfo.environment)

        let protect = ProtectService(host: config.host, apiKey: config.apiKey)
        // `with:` is Protect's high-quality switch, and it is inert: getSnapshot accepts
        // the Bool and never reads it, so the request URL is the same either way. camview
        // used to expose it as `--high-quality`, which promised a full-resolution still it
        // could not deliver. Passing false is honest about what actually happens here.
        // See PeteRichardson/Protect#40.
        let imageData = try await protect.getSnapshot(from: camera, with: false)

        switch destination {
        case .clipboard:
            // Both failures below used to be silent: a nil NSImage skipped the whole block
            // and a false from writeObjects was discarded, so the command printed nothing
            // and exited 0 while the user pasted whatever was on the clipboard before.
            guard let image = NSImage(data: imageData) else {
                throw SnapshotError.undecodableImage(bytes: imageData.count)
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.writeObjects([image]) else {
                throw SnapshotError.clipboardWriteFailed
            }
        case .inlineImage:
            showImageInITerm2(data: imageData)
        case .rawBytes:
            FileHandle.standardOutput.write(imageData)
        }
    }
}

