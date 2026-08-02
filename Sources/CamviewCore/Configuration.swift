//
//  Configuration.swift
//  CamviewCore
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import SimpleConfig

/// Where camview stores its two configuration values.
///
/// The API key is a secret and lives in the macOS Keychain. The Protect host is not, and
/// lives in an App Group `UserDefaults` suite — the app group is what lets the sandboxed
/// camgui read the value the unsandboxed CLI wrote.
public let configItems: [String: any ConfigStorable] = [
    "api-key": SecureConfigItem(
        service: "com.peterichardson.camview",
        key: "api-key"),
    "protect-host": ConfigItem(
        suiteName: "group.com.peterichardson.camview",
        key: "protect-host"),
]

/// The resolved settings needed to talk to a UniFi Protect controller.
///
/// Reads from ``configItems`` at init time. Throws if the API key hasn't been configured;
/// the host falls back to ``defaultHost`` when unset.
public struct Configuration {
    /// Used when `protect-host` has never been written.
    public static let defaultHost = "unvr.local"

    public let host: String
    public let apiKey: String

    public init() throws {
        guard let apiKey = try configItems["api-key"]?.read() else {
            throw ConfigError.unableToLoad(
                reason: "api-key not configured. Run: camview config write api-key <key>")
        }
        self.apiKey = apiKey
        self.host = try configItems["protect-host"]?.read() ?? Self.defaultHost
    }
}
