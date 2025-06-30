//
//  main.swift
//  camview
//
//  Created by Peter Richardson on 6/24/25.
//

import Foundation
import Logging
import ArgumentParser


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

func list<T: ProtectAPIObject>(_ array: [T], csv: Bool = false) {
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
SWITCHING LIVEVIEWS:
You can switch to an available Liveview by passing the Liveview name on the cmd line.
Names are case-INsensitive.
e.g.
camview Driveway

If you don't give a Liveview name, it will try a view called "Default"

NOTE: Currently, camview changes the liveview on only the *first* Viewport
returned by the Protect API.   This will be fixed in a future version.

LISTING VIEWPORTS, LIVEVIEWS AND CAMERAS:
* You can list available Viewports with `camview -p`
* You can list available Liveviews with `camview -v`
* You can list available Cameras with `camview -c`
* You can get more data in csv format by adding `--csv`.  e.g.  `camview -v --csv`


AUTHENTICATION:
Camview requires a ~/.config/camview.json file with Unifi Protect API credentials.
It must contain your Unifi Protect host IP or DNS name, and your API key.  Like this:
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


    @Argument(help: "Name of Liveview to switch to")
    var view: String = "Default"
    
    @Flag(name: [.customShort("v"), .customLong("views")], help: "List Liveviews", )
    var listviews: Bool = false

    @Flag(name: [.customShort("p"), .customLong("ports")], help: "List Viewports", )
    var listports: Bool = false
    
    @Flag(name: [.customShort("c"), .customLong("cameras")], help: "List Cameras", )
    var listcameras: Bool = false

    @Flag(help: "List items as CSV", )
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

        
        if listcameras {
            try await list(protect.getCameras(), csv: csv)
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


