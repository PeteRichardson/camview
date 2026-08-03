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
/// Reads from ``configItems`` at init time. Throws if either value hasn't been configured.
///
/// Neither value has a compiled-in default. `unvr.local` used to stand in for an unset
/// host, but it is one author's hostname rather than a UniFi convention, so it was wrong
/// for everyone else. It also masked failure: because the fallback was identical to the
/// value most likely stored, a *failed* App Group read produced a working-looking host and
/// no error. Requiring the value makes "unset" and "unreadable" both loud.
public struct Configuration {
    public let host: String
    public let apiKey: String

    public init() throws {
        guard let apiKey = try configItems["api-key"]?.read() else {
            throw ConfigError.unableToLoad(
                reason: "api-key not configured. Run: camview config write api-key <key>")
        }
        guard let host = try configItems["protect-host"]?.read() else {
            throw ConfigError.unableToLoad(
                reason: "protect-host not configured. Run: camview config write protect-host <host-or-ip>")
        }
        self.apiKey = apiKey
        self.host = host
    }
}
