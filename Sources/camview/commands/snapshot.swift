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
private enum SnapshotError: Error, CustomStringConvertible {
    case undecodableImage(bytes: Int)
    case clipboardWriteFailed

    var description: String {
        switch self {
        case .undecodableImage(let bytes):
            return "Could not decode the \(bytes) bytes returned by Protect as an image"
        case .clipboardWriteFailed:
            return "The system refused the image; the clipboard is unchanged"
        }
    }
}

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a snapshot of a camera's current view",
    )
    
    @Argument(help: "Name of camera to snapshot")
    var camera: String = "FrontDoor"
    
    @Flag(help: "get hi-resolution snapshot")
    var highQuality: Bool = false
    
    @Flag(name: [.customShort("c"), .customLong("clipboard")], help: "copy to clipboard instead of terminal")
    var sendToClipboard: Bool = false
    
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
    
    func run() async throws {
        let config = try Configuration() 
        
        let protect = ProtectService(host: config.host, apiKey: config.apiKey)
        let imageData = try await protect.getSnapshot(from: camera, with: highQuality)

        if sendToClipboard {  // use clipboard
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
        } else {
            showImageInITerm2(data: imageData)
        }
    }
}

