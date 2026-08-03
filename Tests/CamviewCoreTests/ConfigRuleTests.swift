//
//  ConfigRuleTests.swift
//  CamviewCoreTests
//

import SimpleConfig
import Testing

@testable import CamviewCore

/// A stub so bad *stored* values can be tested without writing them to the real Keychain
/// or App Group suite.
private struct StubItem: ConfigStorable {
    let key: String
    var value: String?

    func read() throws -> String? { value }
    func write(_ value: String) throws {
        Issue.record("write() is not expected during Configuration.init()")
    }

    var description: String { "\(key) = \(value ?? "(not set)")" }
    static func == (lhs: StubItem, rhs: StubItem) -> Bool { lhs.key == rhs.key }
}

private func items(apiKey: String, host: String) -> [String: any ConfigStorable] {
    [
        "api-key": StubItem(key: "api-key", value: apiKey),
        "protect-host": StubItem(key: "protect-host", value: host),
    ]
}

private let goodKey = String(repeating: "a", count: 32)

@Suite("ConfigRule")
struct ConfigRuleTests {

    @Test("a well-formed value is accepted", arguments: [("api-key", 32), ("protect-host", 10)])
    func accepts(key: String, length: Int) {
        #expect(ConfigRule.rejection(for: String(repeating: "a", count: length), key: key) == nil)
    }

    @Test("api-key length is enforced", arguments: [0, 31, 33])
    func apiKeyLength(count: Int) {
        #expect(ConfigRule.rejection(for: String(repeating: "a", count: count), key: "api-key") != nil)
    }

    @Test("an empty or whitespace-bearing host is rejected", arguments: ["", "unvr .local", "a\tb"])
    func hostRejected(host: String) {
        #expect(ConfigRule.rejection(for: host, key: "protect-host") != nil)
    }

    /// A pasted URL is otherwise accepted and becomes `http://https://unvr.local/…`, which
    /// is a well-formed URL that fails DNS with a ~900-byte NSError naming nothing useful.
    @Test(
        "a host carrying a scheme or a path is rejected",
        arguments: ["https://unvr.local", "http://unvr.local", "unvr.local/proxy", "unvr.local/"])
    func hostWithSchemeOrPathRejected(host: String) {
        #expect(ConfigRule.rejection(for: host, key: "protect-host") != nil)
    }

    /// `:` must stay legal — Protect on a non-default port is a real configuration.
    @Test("a host with a port is still accepted", arguments: ["unvr.local:7443", "192.168.1.99:443"])
    func hostWithPortAccepted(host: String) {
        #expect(ConfigRule.rejection(for: host, key: "protect-host") == nil)
    }

    /// Unlike the CLI's write path, these rules do not trim. A value already in storage
    /// with stray whitespace is malformed, and `" unvr.local"` produces the same
    /// unparseable URL as `"unvr .local"`.
    @Test("stored whitespace is reported, not silently trimmed", arguments: [" unvr.local", "unvr.local\n"])
    func noTrimmingOnRead(host: String) {
        #expect(ConfigRule.rejection(for: host, key: "protect-host") != nil)
    }

    @Test("the api-key rejection never contains the value")
    func apiKeyRejectionOmitsSecret() throws {
        let secret = String(repeating: "s", count: 31)
        let reason = try #require(ConfigRule.rejection(for: secret, key: "api-key"))
        #expect(!reason.contains(secret))
        #expect(reason.contains("31"))
    }

    @Test("every config key that exists is a config key that gets validated")
    func everyKeyIsValidated() {
        // Without this, adding a third key to configItems would silently give it no
        // validation: rejection(for:key:) accepts anything it has no rule for.
        #expect(ConfigRule.validatedKeys == Set(configItems.keys))
    }
}

/// `camview config write` is only one of three documented ways to set these values;
/// `README.md` also documents `security add-generic-password` and `defaults write`. A value
/// that arrived by either of those never passed the CLI's validation.
@Suite("Configuration rejects malformed stored values")
struct ConfigurationStoredValueTests {

    /// The one that isn't merely a bad error message. A space makes `URL(string:)` return
    /// nil, and `Protect` force-unwraps it — camview exited 133 (SIGTRAP) printing
    /// nothing, and camgui cannot catch a runtime trap either.
    @Test("a stored host containing a space is rejected instead of reaching URL construction")
    func storedHostWithSpace() {
        #expect(throws: ConfigError.self) {
            try Configuration(items: items(apiKey: goodKey, host: "unvr .local"))
        }
    }

    /// An empty host yields `http:///…`, which is a *valid* URL with an empty host, so the
    /// request quietly went to localhost rather than failing at construction.
    @Test("a stored empty host is rejected rather than resolving to localhost")
    func storedEmptyHost() {
        #expect(throws: ConfigError.self) {
            try Configuration(items: items(apiKey: goodKey, host: ""))
        }
    }

    @Test("a stored api-key of the wrong length is rejected", arguments: ["short", ""])
    func storedBadAPIKey(key: String) {
        #expect(throws: ConfigError.self) {
            try Configuration(items: items(apiKey: key, host: "unvr.local"))
        }
    }

    @Test("well-formed stored values still resolve")
    func storedGoodValues() throws {
        let config = try Configuration(items: items(apiKey: goodKey, host: "unvr.local"))
        #expect(config.apiKey == goodKey)
        #expect(config.host == "unvr.local")
    }

    @Test("a rejection of a stored value says it is the stored one that is wrong")
    func storedRejectionIsDistinguishable() {
        // "not configured" and "configured wrongly" need different messages; the second
        // is not fixed by running `config write` again with the same value.
        do {
            _ = try Configuration(items: items(apiKey: goodKey, host: ""))
            Issue.record("expected an empty stored host to be rejected")
        } catch {
            #expect(String(describing: error).contains("stored"))
        }
    }
}
