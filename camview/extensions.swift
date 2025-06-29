//
//  extensions.swift
//  camview
//
//  Created by Peter Richardson on 6/29/25.
//

import Foundation

extension String {
    func padded(to length: Int) -> String {
        return self.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

extension Array {
    func asyncMap<T>(
        _ transform: @escaping (Element) async throws -> T
    ) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}

