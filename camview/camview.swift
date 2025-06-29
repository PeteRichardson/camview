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

    @Argument(help: "Name of multi-view to switch to")
    var view: String = "Driveway"
    
    @Flag(name: [.customShort("v"), .customLong("views")], help: "List Liveviews", )
    var listviews: Bool = false

    @Flag(name: [.customShort("p"), .customLong("ports")], help: "List Viewports", )
    var listports: Bool = false

    @Flag(name: [.customShort("c"), .customLong("csv")], help: "List items as CSV", )
    var csv: Bool = false

    mutating func run() async throws {
        let url = URL(fileURLWithPath: "/Users/pete/bin/config.json")
        let data = try Data(contentsOf: url)
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


