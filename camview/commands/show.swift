//
//  show.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser

struct Show: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set a Liveview for a Viewport",
    )
    
    @Argument(help: "Name of Liveview to show")
    var liveview: String = "Front Door"

    @Argument(help: "Name of Viewport to change")
    var viewport: String = "Front Door"

    
    func run() async throws {
        guard let config = Configuration() else {
            throw FileNotFoundError(path: "~/.config/camview.json")
        }
        
        let protect = ProtectService(host: config.unifi.protect.api.host, apiKey: config.unifi.protect.api.apiKey)

        let viewportId = try await protect.viewports().first!.id
        let lcView = liveview.lowercased()
        for liveview in try await protect.liveviews() {
            if liveview.name.lowercased() == lcView {
                try await protect.changeViewportView(on: viewportId, to: liveview.id)
                return
            }
        }
        print("# ERROR: \(liveview) not found.  Try one of the following view names:")
        try await list(protect.liveviews())
    }
}
