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

    typealias ViewportMap = [String: String]
    typealias MultiviewMap = [String: String]

    struct Protect: Codable {
        let api: ProtectAPI
        let viewports: ViewportMap
        let multiviews: MultiviewMap
    }

    struct Unifi: Codable {
        let protect: Protect
    }

    let unifi: Unifi
}



@main
struct CamView : AsyncParsableCommand {

    @Argument(help: "Name of multi-view to switch to")
    var view: String = "Driveway"
    
    mutating func run() async throws {
        let url = URL(fileURLWithPath: "config.json")
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Config.self, from: data)

        // Usage
        let protect = Protect(host: config.unifi.protect.api.host, apiKey: config.unifi.protect.api.apiKey)
        let viewports = try await protect.getViewports()
        for vp in viewports {
            print("\(vp.name) = \(vp.id)")
        }
        
        print("You want me to switch to \(view)")
        
    }
}


