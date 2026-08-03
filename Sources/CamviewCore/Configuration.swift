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

    /// - Parameter items: where to read the values from. Defaults to ``configItems``, the
    ///   real Keychain and App Group storage. Tests substitute stubs: without this
    ///   parameter the failure paths below are unreachable, because reaching them would
    ///   mean deleting the developer's own credentials.
    public init(items: [String: any ConfigStorable] = configItems) throws {
        guard let apiKey = try items["api-key"]?.read() else {
            throw ConfigError.unableToLoad(
                reason: "api-key not configured. Run: camview config write api-key <key>")
        }
        guard let host = try items["protect-host"]?.read() else {
            throw ConfigError.unableToLoad(
                reason: "protect-host not configured. Run: camview config write protect-host <host-or-ip>")
        }

        // Values can reach storage without passing through `camview config write` — the
        // README documents `security add-generic-password` and `defaults write` as
        // alternatives — so being present is not the same as being usable. Checking here
        // covers every entry point, since this initializer is the one gate both the CLI
        // and camgui pass through.
        for (key, value) in [("api-key", apiKey), ("protect-host", host)] {
            if let reason = ConfigRule.rejection(for: value, key: key) {
                throw ConfigError.unableToLoad(reason: "stored \(reason)")
            }
        }

        self.apiKey = apiKey
        self.host = host
    }
}
