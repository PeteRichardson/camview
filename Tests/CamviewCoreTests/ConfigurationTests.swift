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

    // A fourth test asserting `Configuration.defaultHost == "unvr.local"` was removed
    // here: that fallback no longer exists. The behaviour that replaced it — `init()`
    // throwing when `protect-host` is unset — can't be tested yet, because `Configuration`
    // reads the real Keychain and App Group suite with no seam to substitute them. Adding
    // that seam is #4, which builds on this branch.
}
