//
//  protect.swift
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
        self.headers = [
            "X-API-KEY": apiKey,
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
        let result = try T.parse(data)
        cache = result
        return result
    }

    func fetchData(for path: String, accepting mimetype: MIMEType = .json) async throws -> Data {
        let url = base_url.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue(mimetype.rawValue, forHTTPHeaderField: "Accept")

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
                userInfo: [
                    NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                ]
            )
        }
    }

    func getSnapshot(from camera: String, with quality: Bool) async throws -> Data {
        guard let cameraId = try await lookupCameraId(byName: camera) else {
            throw NSError(domain: "ProtectService", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Camera '\(camera)' not found"
            ])
        }

        let url = base_url.appendingPathComponent("/cameras/\(cameraId)/snapshot")
        return try await fetch(from: url, headers: headers)
    }

    func lookupLiveviewName(byId id: String) async throws -> String? {
        try await liveviews().first(where: { $0.id == id })?.name
    }

    func lookupCameraId(byName name: String) async throws -> String? {
        try await cameras().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

    func lookupViewportId(byName name: String) async throws -> String? {
        try await viewports().first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }

    func changeViewportView(on viewportId: String, to liveviewId: String) async throws {
        let url = base_url.appendingPathComponent("/viewers/\(viewportId)")
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
