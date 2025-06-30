//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/25/25.
//

import Foundation
import Logging

var logger = Logger(label: "protect")


func fetchJSON(from url: URL, headers: [String: String]) async throws -> Data {
    var request = URLRequest(url: url)
    headers.forEach { key, value in
        request.setValue(value, forHTTPHeaderField: key)
    }

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }

    return data
}


struct Viewport: Decodable, Comparable, CustomCSVConvertible {
    
    var id: String
    var liveview: String
    var modelKey: String
    var name: String
    var state: String
    var streamLimit: Int
    
    static var csvHeader : String = "name,id,liveview,modelKey,state,streamLimit"

    var description: String {
        "\(name.padded(to:17)) <\(id)> (viewing '\(liveview)')"
    }
    func csvDescription() -> String {
        "\(name),\(id),\(liveview),\(modelKey),\(state),\(streamLimit)"
    }
    
    static func < (lhs: Viewport, rhs: Viewport) -> Bool {
        return lhs.name < rhs.name
    }
    static func == (lhs: Viewport, rhs: Viewport) -> Bool {
        lhs.name == rhs.name
    }
    
}

struct Slot: Decodable {
    var cameras: [String]
    var cycleMode: String
    var cycleInterval: Int
}

struct Liveview: Decodable, Comparable, CustomCSVConvertible {
    
    var id: String
    var modelKey: String
    var name: String
    var isDefault: Bool
    var isGlobal: Bool
    var owner: String
    var layout: Int
    var slots: [Slot]

    static var csvHeader : String = "name,id,isDefault,isGlobal,owner,layout"

    var description: String {
        "\(name.padded(to:17)) <\(id)> \(isDefault ? "(default)" : "")"
    }
    
    func csvDescription() -> String {
        "\(name),\(id),\(isDefault),\(isGlobal),\(owner),\(layout)"
    }
    
    static func < (lhs: Liveview, rhs: Liveview) -> Bool {
        return lhs.name < rhs.name
    }
    static func == (lhs: Liveview, rhs: Liveview) -> Bool {
        lhs.name == rhs.name
    }
}


actor Protect {
    private var _viewports: [Viewport]?
    private var _liveviews: [Liveview]?
    
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
        
        // Now that we have the list of viewports, we can lookup the currently
        // visible Liveview (we have its id) and get the name, which is
        // easier for the users to understand.
        // Viewport is a struct, so we can't modify them.  We have to copy.
        // Need asyncMap extension on Array for this to work.
        let updatedViewports = try await viewports.asyncMap { viewport in
            var copy = viewport
            copy.liveview = try await self.lookupLiveviewName(byId: viewport.liveview)!
            return copy
        }
        _viewports = updatedViewports.sorted()
        
        return _viewports!
    }
    
    func getLiveviews() async throws -> [Liveview] {
        if let cached = _liveviews {
            return cached
        }
        let url = URL(string: "\(baseAPIUrl)/v1/liveviews")!
        
        let data = try await fetchJSON(from: url, headers: headers)
        let liveviews = try JSONDecoder().decode([Liveview].self, from: data)
        _liveviews = liveviews.sorted()
        return _liveviews!
    }
    
    func lookupLiveviewName(byId id: String) async throws -> String? {
        let liveviews = try await getLiveviews()
        return liveviews.first(where: { $0.id == id })?.name
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
    
