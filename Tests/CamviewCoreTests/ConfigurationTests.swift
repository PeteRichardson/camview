//
//  ConfigurationTests.swift
//  CamviewCoreTests
//

import SimpleConfig
import Testing

@testable import CamviewCore

/// These guard the storage identifiers. If any of them change, an existing install
/// silently stops seeing the values it already wrote — the API key appears unset and the
/// host falls back to the default, with no error to explain why.
@Suite("Config storage identifiers")
struct ConfigStorageIdentifierTests {

    @Test("configItems exposes exactly the two known keys")
    func knownKeys() {
        #expect(Set(configItems.keys) == ["api-key", "protect-host"])
    }

    @Test("api-key is a Keychain item under the camview service")
    func apiKeyStorage() throws {
        let item = try #require(configItems["api-key"] as? SecureConfigItem)
        #expect(item.service == "com.peterichardson.camview")
        #expect(item.key == "api-key")
    }

    @Test("protect-host lives in the shared App Group suite")
    func protectHostStorage() throws {
        let item = try #require(configItems["protect-host"] as? ConfigItem)
        // The App Group — not a plain UserDefaults domain — is what lets the sandboxed
        // camgui read what the unsandboxed CLI wrote.
        #expect(item.suiteName == "group.com.peterichardson.camview")
        #expect(item.key == "protect-host")
    }

    // A test asserting `Configuration.defaultHost == "unvr.local"` used to live here. That
    // fallback is gone; what replaced it is covered by `ConfigurationInitTests` below,
    // which the `items:` seam made reachable.
}

/// A `ConfigStorable` backed by a plain value, so the failure paths are reachable without
/// deleting the developer's own Keychain entry to get at them.
private struct StubItem: ConfigStorable {
    let key: String
    var value: String?
    var readError: (any Error)?

    func read() throws -> String? {
        if let readError { throw readError }
        return value
    }

    func write(_ value: String) throws {
        Issue.record("write() is not expected during Configuration.init()")
    }

    // `ConfigStorable` inherits `Comparable` and `CustomStringConvertible`. SimpleConfig
    // supplies `<` publicly but its `description` default is internal to that module, and
    // `==` has no default at all, so both are spelled out here rather than synthesized.
    var description: String { "\(key) = \(value ?? "(not set)")" }
    static func == (lhs: StubItem, rhs: StubItem) -> Bool { lhs.key == rhs.key }
}

private struct StubError: Error {}

private func items(apiKey: String?, host: String?) -> [String: any ConfigStorable] {
    [
        "api-key": StubItem(key: "api-key", value: apiKey),
        "protect-host": StubItem(key: "protect-host", value: host),
    ]
}

/// `Configuration.init()` is the single gate every command passes through, and until the
/// `items:` seam existed none of its failure paths could be exercised — reaching them
/// meant unsetting real credentials.
@Suite("Configuration.init")
struct ConfigurationInitTests {

    @Test("both values present resolves, without swapping them")
    func bothPresent() throws {
        let config = try Configuration(items: items(apiKey: "KEY", host: "example.local"))
        // Asserted separately because both are `String`: transposing the two assignments
        // would still compile and still pass a test that only checked one.
        #expect(config.apiKey == "KEY")
        #expect(config.host == "example.local")
    }

    @Test("a missing api-key throws and names the command that fixes it")
    func missingAPIKey() {
        #expect(throws: ConfigError.self) {
            try Configuration(items: items(apiKey: nil, host: "example.local"))
        }
        let message = message(from: items(apiKey: nil, host: "example.local"))
        #expect(message?.contains("camview config write api-key") == true)
    }

    /// The behaviour that replaced `defaultHost`. Before #16 this case silently produced
    /// `unvr.local` — indistinguishable from a correctly configured install.
    @Test("a missing protect-host throws and names the command that fixes it")
    func missingHost() {
        #expect(throws: ConfigError.self) {
            try Configuration(items: items(apiKey: "KEY", host: nil))
        }
        let message = message(from: items(apiKey: "KEY", host: nil))
        #expect(message?.contains("camview config write protect-host") == true)
    }

    @Test("an unreadable value is a failure, not an empty host")
    func readErrorPropagates() {
        // Distinct from "unset": a Keychain or App Group read that *fails* must not be
        // quietly turned into a missing value.
        let broken: [String: any ConfigStorable] = [
            "api-key": StubItem(key: "api-key", value: "KEY"),
            "protect-host": StubItem(key: "protect-host", value: "h", readError: StubError()),
        ]
        #expect(throws: (any Error).self) {
            try Configuration(items: broken)
        }
    }

    @Test("an empty storage map throws rather than trapping on the missing key")
    func emptyItems() {
        #expect(throws: ConfigError.self) {
            try Configuration(items: [:])
        }
    }

    private func message(from items: [String: any ConfigStorable]) -> String? {
        do {
            _ = try Configuration(items: items)
            return nil
        } catch {
            return String(describing: error)
        }
    }
}
