//
//  main.swift
//  camview
//
//  Created by Peter Richardson on 6/24/25.
//

import Foundation
import Logging
import ArgumentParser

protocol CustomCSVConvertible: CustomStringConvertible {
    static var csvHeader: String { get }
    func csvDescription() -> String
}


struct Config: Codable {
    struct ProtectAPI: Codable {
        let host: String
        let apiKey: String
    }

    struct Protect: Codable {
        let api: ProtectAPI
    }

    struct Unifi: Codable {
        let protect: Protect
    }

    let unifi: Unifi
}

func list<T: CustomCSVConvertible>(_ array: [T], csv: Bool = false) {
    if csv {
        print(T.csvHeader)
    }
    for item in array {
        print(csv ? item.csvDescription() : item.description)
    }
}

@main
struct CamView : AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "CLI to control a Unifi Protect Viewport.",
        discussion: """
You can switch to a Liveview by passing the Liveview name on the cmd line.
Names are case-INsensitive.
e.g.   camview Driveway

If you don't give a Liveview name, it will try a view called "Default"

You can list Viewports with -p and Liveviews with -v
You'll get a summary view of names and ids.
You can get more data in csv format by specifying -c.


Limitations:
• Currently it uses only the first Viewport that the Protect API returns.
• The default

Authentication:
Camview requires a ~/.config/camview.json file with Unifi Protect API credentials.
It must contain your Unifi Protect host IP or DNS name, and your API token.  Like this:
{
    "unifi" : {
        "protect" : {
            "api": {
                "host": "192.168.1.1",
                "apiKey": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
            }
        }
    }
}
"""
)


    @Argument(help: "Name of multi-view to switch to")
    var view: String = "Default"
    
    @Flag(name: [.customShort("v"), .customLong("views")], help: "List Liveviews", )
    var listviews: Bool = false

    @Flag(name: [.customShort("p"), .customLong("ports")], help: "List Viewports", )
    var listports: Bool = false

    @Flag(name: [.customShort("c"), .customLong("csv")], help: "List items as CSV", )
    var csv: Bool = false

    mutating func run() async throws {
        // find the config file
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configFile = home.appendingPathComponent(".config").appendingPathComponent("camview.json")

        let data = try Data(contentsOf: configFile.standardizedFileURL)
        let config = try JSONDecoder().decode(Config.self, from: data)
        let protect = Protect(host: config.unifi.protect.api.host, apiKey: config.unifi.protect.api.apiKey)
        
        if listviews {
            try await list(protect.getLiveviews(), csv: csv)
            return
        }

        if listports {
            try await list(protect.getViewports(), csv: csv)
            return
        }
        
        let viewportId = try await protect.getViewports().first!.id
        let lcView = view.lowercased()
        for liveview in try await protect.getLiveviews() {
            if liveview.name.lowercased() == lcView {
                try await protect.changeViewportView(on: viewportId, to: liveview.id)
                return
            }
        }
        print("# ERROR: \(view) not found.  Try one of the following view names:")
        try await list(protect.getLiveviews())
    }
}


