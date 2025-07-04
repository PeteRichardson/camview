//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/25/25.
//

import Foundation
import Logging
import AppKit

var logger = Logger(label: "protect")

enum MIMEType: String {
    case json = "application/json"
    case jpeg = "application/jpeg"
}


func fetch(from url: URL, headers: [String: String]) async throws -> Data {
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


class ProtectService {
    private var cachedCameras: [Camera]? = nil         // cache the camera values
    private var cachedLiveviews: [Liveview]? = nil     // cache the liveview values
    private var cachedViewports: [Viewport]? = nil     // cache the viewport values

    private let host: String
    private let apiKey: String
    var base_url: URL {
        URL(string: "http://\(host)/proxy/protect/integration/v1")!
    }
    private var headers: [String: String] = [:]
    
    init(host: String, apiKey: String) {
        self.host = host
        self.apiKey = apiKey
        self.headers = [
            "X-API-KEY": self.apiKey,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
    func cameras() async throws -> [Camera] {
        try await fetchAndCache(cache: &cachedCameras)
    }

    func liveviews() async throws -> [Liveview] {
        try await fetchAndCache(cache: &cachedLiveviews)
    }

    func viewports() async throws -> [Viewport] {
        try await fetchAndCache(cache: &cachedViewports)
    }
    
    private func fetchAndCache<T: ProtectFetchable>(cache: inout [T]?) async throws -> [T] {
        if let cached = cache {
            return cached
        }
        let data = try await fetchData(for: T.urlSuffix, accepting: .json)
        cache = try T.parse(data)
        return cache!
    }
    
    func fetchData(for path: String, accepting mimetype: MIMEType = .json) async throws -> Data {
        let url = base_url.appendingPathComponent(path)
        var request = URLRequest(url: url)
        let apiKey = try Keychain.LoadApiKey()
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue(mimetype.rawValue, forHTTPHeaderField: "accepts")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
         
        return data
    }
    
    func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "ProtectService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)]
            )
        }
    }
    
    func getSnapshot(from camera: String, with quality: Bool) async throws -> Data {
        // use {{base_url}}/cameras/<camera_id>/snapshot
        // and accept = image/jpeg
        // and highQuailty = true | false
        
        guard let camera_id = try await lookupCameraId(byName: camera) else {
            throw NSError(domain: "ProtectServce", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Camera not found"])
        }
        let url = base_url.appendingPathComponent(String(format: "/cameras/%@/snapshot", camera_id))
        let imageData = try await fetch(from: url, headers: headers)
        return imageData
    }
    
    func lookupLiveviewName(byId id: String) async throws -> String? {
        let liveviews = try await liveviews()
        return liveviews.first(where: { $0.id == id })?.name
    }
    
    func lookupCameraId(byName name: String) async throws -> String? {
        let cameras = try await cameras()
        return cameras.first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }
    
    func changeViewportView(on viewportId: String,to liveviewId: String) async throws {
        let url = base_url.appendingPathComponent(String(format: "/viewers/%@", viewportId))
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
    
