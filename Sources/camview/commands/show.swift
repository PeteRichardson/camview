//
//  show.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser
import CamviewCore
import Protect
import SimpleConfig

/// Diagnostics belong on stderr, so redirecting stdout captures results only.
private func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

struct Show: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set a Liveview for a Viewport"
    )

    @Argument(help: "Name of Liveview to show")
    var liveview: String = "Default"

    /// An option rather than a second positional: with two optional positionals,
    /// `camview show MyViewport` silently parsed the viewport name as a liveview.
    @Option(
        name: [.customShort("v"), .customLong("viewport")],
        help: "Name of Viewport to change (default: the first one)")
    var viewport: String?

    func run() async throws {
        let config = try Configuration()

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
            printError("# ERROR: \(liveview) not found. Try one of the following view names:")
            for candidate in liveviews {
                printError(candidate.description)
            }
            throw ConfigError.unableToLoad(reason: "Liveview '\(liveview)' not found")
        }

        // Change the liveview on the selected viewport
        try await protect.changeViewportView(on: viewportId, to: liveviewMatch.id)
    }
}
