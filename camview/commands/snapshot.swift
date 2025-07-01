//
//  Show.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser

struct Snapshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a snapshot of a camera's current view",
    )
    
    @Argument(help: "Name of camera to snapshot")
    var camera: String = "Front Door"
    
    @Flag(help: "get hi-resolution snapshot")
    var highQuality: Bool = false
    
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
        
        let protect = Protect(host: config.unifi.protect.api.host, apiKey: config.unifi.protect.api.apiKey)
        let imagedata = try await protect.getSnapshot(from: camera, with: highQuality)
        showImageInITerm2(data: imagedata)
    }
}

