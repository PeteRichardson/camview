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

    @Test("host falls back to unvr.local when protect-host is unset")
    func defaultHost() {
        #expect(Configuration.defaultHost == "unvr.local")
    }
}
