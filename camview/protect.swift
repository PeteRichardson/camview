//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/25/25.
//

import Foundation
import Logging

var logger = Logger(label: "protect")

struct Viewport: Decodable {
    var id: String
    var liveview: String
    var modelKey: String
    var name: String
    var state: String
    var streamLimit: Int

}

class Protect {
    private var _viewports: [Viewport]? = nil
    private let host: String
    private let apiKey: String
    private var url: String
    
    init(host: String, apiKey: String) {
        self.host = host
        self.apiKey = apiKey
        self.url = "https://\(host)/proxy/protect/integration"
    }
    
    
    func getViewports() async throws -> [Viewport] {
        if let cached = _viewports {
            return cached
        }
        let url = URL(string: "\(url)/v1/viewers")!
        let headers = [
            "X-API-KEY": self.apiKey,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        let data = try await fetchJSON(from: url, headers: headers)
        let viewports = try JSONDecoder().decode([Viewport].self, from: data)

        print(viewports)        // TODO: decode JSON
        _viewports = []
        return _viewports!
    }
}
    
