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


struct CamViewApp : ParsableCommand {
    @Argument(help: "Name of multi-view to switch to")
    var view: String
    
    mutating func run() throws {
        print(FileManager.default.currentDirectoryPath)
        let url = URL(fileURLWithPath: "config.json")
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Config.self, from: data)

        // Usage
        print(config.unifi.protect.api.apiKey)
        print(config.unifi.protect.viewports["office"] ?? "No viewport")
        
        print("You want me to switch to \(view)")
        
    }
}

@main
struct MainApp {
    static func main() {
        CamViewApp.main()
    }
}
