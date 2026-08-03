//
//  ConfigValidationTests.swift
//  CamviewCLITests
//

import ArgumentParser
import CamviewCore
import Testing

@testable import camview

/// `config write` used to store whatever it was given. A mistyped api-key then failed as an
/// opaque HTTP error from an unrelated command, with nothing pointing back at the write.
@Suite("config write validation")
struct ConfigValidationTests {

    // MARK: api-key

    @Test("a 32-character api-key is accepted")
    func apiKeyCorrectLength() throws {
        let key = String(repeating: "a", count: 32)
        #expect(try ConfigValue.validated(key, for: "api-key") == key)
    }

    @Test("a short api-key is rejected", arguments: [0, 1, 31])
    func apiKeyTooShort(count: Int) {
        #expect(throws: ValidationError.self) {
            try ConfigValue.validated(String(repeating: "a", count: count), for: "api-key")
        }
    }

    @Test("a long api-key is rejected", arguments: [33, 64])
    func apiKeyTooLong(count: Int) {
        #expect(throws: ValidationError.self) {
            try ConfigValue.validated(String(repeating: "a", count: count), for: "api-key")
        }
    }

    @Test("a pasted api-key with surrounding whitespace is trimmed, not rejected")
    func apiKeyTrimmed() throws {
        // The failure this prevents is the nastiest of the set: a trailing newline off a
        // web UI stores a 33-character key that looks correct everywhere it's displayed.
        let key = String(repeating: "a", count: 32)
        #expect(try ConfigValue.validated("  \(key)\n", for: "api-key") == key)
    }

    @Test("the api-key rejection message never contains the value")
    func apiKeyErrorOmitsSecret() {
        // `config read` obfuscates this secret deliberately (#2). An error message must
        // not be the thing that prints it.
        let secret = String(repeating: "s", count: 31)
        do {
            _ = try ConfigValue.validated(secret, for: "api-key")
            Issue.record("expected a 31-character key to be rejected")
        } catch {
            let message = String(describing: error)
            #expect(!message.contains(secret))
            #expect(message.contains("31"))  // the length is what's reported instead
        }
    }

    // MARK: protect-host

    @Test("a plausible host is accepted", arguments: ["unvr.local", "192.168.1.99", "u"])
    func hostAccepted(host: String) throws {
        #expect(try ConfigValue.validated(host, for: "protect-host") == host)
    }

    @Test("an empty or whitespace-only host is rejected", arguments: ["", "   ", "\n", "\t"])
    func hostEmptyRejected(host: String) {
        #expect(throws: ValidationError.self) {
            try ConfigValue.validated(host, for: "protect-host")
        }
    }

    @Test("a host containing whitespace is rejected")
    func hostInternalWhitespaceRejected() {
        // No hostname or IP contains a space; accepting one guarantees a later DNS failure.
        #expect(throws: ValidationError.self) {
            try ConfigValue.validated("unvr .local", for: "protect-host")
        }
    }

    @Test("a host with surrounding whitespace is trimmed")
    func hostTrimmed() throws {
        #expect(try ConfigValue.validated("  unvr.local \n", for: "protect-host") == "unvr.local")
    }

    // MARK: drift guard

    @Test("every config key that exists is a config key that gets validated")
    func everyKeyIsValidated() {
        // Without this, adding a third key to configItems would silently give it no
        // validation at all — the default branch in validated(_:for:) accepts anything.
        #expect(ConfigValue.validatedKeys == Set(configItems.keys))
    }
}
