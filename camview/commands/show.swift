//
//  show.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser
import Protect

struct Show: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set a Liveview for a Viewport"
    )

    @Argument(help: "Name of Liveview to show")
    var liveview: String = "Default"

    @Argument(help: "Name of Viewport to change")
    var viewport: String? = nil

    func run() async throws {
        do {
            guard let config = Configuration() else {
                throw ConfigError.unableToLoad(reason: "Unknown configuration")
            }

            let protect = ProtectService(host: config.host, apiKey: config.apiKey)

            // Get list of viewports
            let viewports = try await protect.viewports()
            let viewportId: String

            if let viewportName = viewport {
                guard let id = viewports.first(where: { $0.name.lowercased() == viewportName.lowercased() })?.id else {
                    throw ConfigError.unableToLoad(reason: "Viewport named '\(viewportName)' not found")
                }
                viewportId = id
            } else {
                guard let firstViewport = viewports.first else {
                    throw ConfigError.unableToLoad(reason: "No viewports available")
                }
                viewportId = firstViewport.id
            }

            // Get list of liveviews
            let liveviews = try await protect.liveviews()
            let lcView = liveview.lowercased()

            guard let liveviewMatch = liveviews.first(where: { $0.name.lowercased() == lcView }) else {
                print("# ERROR: \(liveview) not found. Try one of the following view names:")
                list(liveviews)
                throw ConfigError.unableToLoad(reason: "Liveview '\(liveview)' not found")
            }

            // Change the liveview on the selected viewport
            try await protect.changeViewportView(on: viewportId, to: liveviewMatch.id)
        } catch {
            throw ConfigError.unknown(error)
        }
    }
}
