//
//  Show.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser
import AppKit

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
        guard let config = Configuration() else {
            throw FileNotFoundError(path: "~/.config/camview.json")
        }
        
        let protect = ProtectService(host: config.host, apiKey: config.apiKey)
        let imageData = try await protect.getSnapshot(from: camera, with: highQuality)

        if sendToClipboard {  // use clipboard
            if let image = NSImage(data: imageData) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            }
        } else {
            showImageInITerm2(data: imageData)
        }
    }
}

