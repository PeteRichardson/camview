//
//  List.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser

struct FileNotFoundError: Error {
    let path: String
}

extension FileNotFoundError: LocalizedError {
    var errorDescription: String? {
        "File not found at path: \(path)"
    }
}


func list<T: ProtectFetchable>(_ array: [T], format: String = "summary") {
    var desc: String
    
    // HEADER
    if format.lowercased() == "csv" {
        print(T.csvHeader)
    }
    
    // LIST ITEMS
    for item in array {
        switch format.lowercased() {
        case "csv":
            desc = item.csvDescription()
        default:
            desc = item.description
        }
        
        print(desc)
    }
    
    // FOOTER
    // None yet.
}

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show a list of liveviews, viewports or cameras",
    )
    
    @Argument(help: "Type of object to list (liveviews | viewports | cameras)")
    var object: String = "liveviews"
    
    @Option(name: .shortAndLong, help: "Format to use (summary| csv)")
    var format: String = "summary"
    
    func run() async throws {
        guard let config = Configuration() else {
            throw FileNotFoundError(path: "~/.config/camview.json")
        }
        
        let protect = ProtectService(host: config.host, apiKey: config.apiKey)

        switch object.lowercased() {
        case "liveviews":
            try await list(protect.liveviews(), format: format)
        case "viewports":
            try await list(protect.viewports(), format: format)
        case "cameras":
            try await list(protect.cameras(), format: format)
        default:
            throw ValidationError("Invalid object type: \(object). Use one of: liveviews, viewports, cameras.")
        }

    }
}
