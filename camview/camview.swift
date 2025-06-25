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


func printViewports(_ protect: Protect) async throws {
    print("VIEWPORTS:\n---------------------------------")
    let viewports = try await protect.getViewports()
    for vp in viewports {
        print("\(vp.name) = \(vp.id)")
    }
}

func printLiveviews(_ protect: Protect) async throws {
    print("LIVEVIEWS:\n---------------------------------")
    let liveviews = try await protect.getLiveviews()
    for lv in liveviews {
        print("\(lv.name) = \(lv.id) [isDefault: \(lv.isDefault)], isGlobal: \(lv.isGlobal)]")
    }
}




@main
struct CamView : AsyncParsableCommand {

    @Argument(help: "Name of multi-view to switch to")
    var view: String = "Driveway"
    
    mutating func run() async throws {
        let url = URL(fileURLWithPath: "/Users/pete/bin/config.json")
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Config.self, from: data)

        let protect = Protect(host: config.unifi.protect.api.host, apiKey: config.unifi.protect.api.apiKey)
        
        
        let viewportId = try await protect.getViewports().first!.id
        let lcView = view.lowercased()
        for liveview in try await protect.getLiveviews() {
            if liveview.name.lowercased() == lcView {
                try await protect.changeViewportView(on: viewportId, to: liveview.id)
                return
            }
        }
        
    }
}


