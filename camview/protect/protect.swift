//
//  protect.swift
//  camview
//
//  Created by Peter Richardson on 6/25/25.
//

import Foundation
import AppKit
import OSLog


enum MIMEType: String {
    case json = "application/json"
    case jpeg = "application/jpeg"
}


class ProtectService {
    let logger = Logger(subsystem: "com.peterichardson.camview", category: "ProtectService")

    private var cachedCameras: [Camera]? = nil
    private var cachedLiveviews: [Liveview]? = nil
    private var cachedViewports: [Viewport]? = nil

    private let host: String
    private let apiKey: String

    private var headers: [String: String] = [:]

    var base_url: URL {
        URL(string: "http://\(host)/proxy/protect/integration/v1")!
    }

    init(host: String, apiKey: String) {
        self.host = host
        self.apiKey = apiKey
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
    
    func getSnapshot(from camera: String, with quality: Bool) async throws -> Data {
        logger.debug("Getting snapshot for camera '\(camera, privacy: .public)'")
        guard let cameraId = try await lookupCameraId(byName: camera) else {
            throw NSError(domain: "ProtectService", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Camera '\(camera)' not found"
            ])
        }

        let url = base_url.appendingPathComponent("/cameras/\(cameraId)/snapshot")
        return try await request(url: url)
    }
    
    func changeViewportView(on viewportId: String, to liveviewId: String) async throws {
        let body = ["liveview": liveviewId]
        let requestBody = try JSONEncoder().encode(body)
        _ = try await request(path: "/viewers/\(viewportId)", method: "PATCH", body: requestBody)
    }
    
    
    // HELPER FUNCTIONS

    
    private func fetchAndCache<T: ProtectFetchable>(cache: inout [T]?) async throws -> [T] {
        if let cached = cache {
            logger.debug("Returning cached result for \(T.urlSuffix)")
            return cached
        }
        logger.debug("Loading \(T.urlSuffix, privacy: .public) data from server.  Should happen only once!")
        let data = try await request(path: T.urlSuffix, accepting: .json)
        let result = try T.parse(data)
        cache = result
        return result
    }
    
    func request(path: String? = nil, url: URL? = nil, headers: [String: String]? = nil, method: String? = nil, body: Data? = nil, accepting mimetype: MIMEType? = .json) async throws -> Data {
        let requestId = "Req " + String(UUID().uuidString.prefix(6))
        let resolvedURL = url ?? (path.map { base_url.appendingPathComponent($0) })!
       logger.debug("[\(requestId, privacy: .public)] Preparing: \(resolvedURL, privacy: .public)")

        var request = URLRequest(url: resolvedURL)
        let allHeaders = headers ?? [
            "X-API-KEY": apiKey,
            "Content-Type": "application/json",
            "Accept": mimetype?.rawValue ?? "application/json"
        ]
       
        allHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
       logger.trace("[\(requestId, privacy: .public)] Request headers: \(request.allHTTPHeaderFields ?? [:], privacy: .public)")
       if let method = method {
            request.httpMethod = method
        }
        if let body = body {
            request.httpBody = body
        }

       logger.info("[\(requestId, privacy: .public)] Sending request to \(request.url?.absoluteString ?? "unknown URL", privacy: .public)")

       let (data, response) = try await URLSession.shared.data(for: request)

       guard let httpResponse = response as? HTTPURLResponse else {
           throw URLError(.badServerResponse)
       }
       logger.debug("[\(requestId, privacy: .public)] Received response: \(httpResponse.statusCode)")

       guard (200...299).contains(httpResponse.statusCode) else {
           throw NSError(
               domain: "ProtectService",
               code: httpResponse.statusCode,
               userInfo: [
                   NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
               ]
           )
       }
       
       let bodySnippet = String(decoding: data.prefix(200), as: UTF8.self)
       logger.debug("[\(requestId, privacy: .public)] Response body (first 200 chars): \(bodySnippet, privacy: .public)")

       return data
    }

    func lookupLiveviewName(byId id: String) async throws -> String? {
        logger.debug("\tGetting liveview name for \(id, privacy: .public)")
        return try await liveviews().first(where: { $0.id == id })?.name
    }

    func lookupCameraId(byName name: String) async throws -> String? {
        logger.debug("\tGetting camera id for \(name, privacy: .public)")
        return try await cameras().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

    func lookupViewportId(byName name: String) async throws -> String? {
        logger.debug("\tGetting viewport id for \(name, privacy: .public)")
        return try await viewports().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

}
