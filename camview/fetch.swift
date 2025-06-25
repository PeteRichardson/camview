//
//  fetch.swift
//  camview
//
//  Created by Peter Richardson on 6/25/25.
//

import Foundation

//enum HTTPError: Error {
//    case badStatusCode(Int)
//    case invalidJSON
//}

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
