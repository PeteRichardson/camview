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

struct Slot: Decodable {
    var cameras: [String]
    var cycleMode: String
    var cycleInterval: Int
}

struct Liveview: Decodable {
    var id: String
    var modelKey: String
    var name: String
    var isDefault: Bool
    var isGlobal: Bool
    var owner: String
    var layout: Int
    var slots: [Slot]
}

class Protect {
    private var _viewports: [Viewport]? = nil
    private var _liveviews: [Liveview]? = nil
    
    private let host: String
    private let apiKey: String
    private var baseAPIUrl: String
    private var headers: [String: String] = [:]
    
    init(host: String, apiKey: String) {
        self.host = host
        self.apiKey = apiKey
        self.baseAPIUrl = "https://\(host)/proxy/protect/integration"
        self.headers = [
            "X-API-KEY": self.apiKey,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
    
    
    func getViewports() async throws -> [Viewport] {
        if let cached = _viewports {
            return cached
        }
        let url = URL(string: "\(baseAPIUrl)/v1/viewers")!
        
        let data = try await fetchJSON(from: url, headers: headers)
        let viewports = try JSONDecoder().decode([Viewport].self, from: data)
        _viewports = viewports
        return viewports
    }
    
    func getLiveviews() async throws -> [Liveview] {
        if let cached = _liveviews {
            return cached
        }
        let url = URL(string: "\(baseAPIUrl)/v1/liveviews")!
        
        let data = try await fetchJSON(from: url, headers: headers)
        let liveviews = try JSONDecoder().decode([Liveview].self, from: data)
        _liveviews = liveviews
        return liveviews
    }
    
    func changeViewportView(on viewportId: String,to liveviewId: String) async throws {
        let url = URL(string: "\(baseAPIUrl)/v1/viewers/\(viewportId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let body = ["liveview": liveviewId]
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
        

}
    
