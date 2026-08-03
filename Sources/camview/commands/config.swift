//
//  config.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import ArgumentParser
import CamviewCore
import Foundation
import SimpleConfig

/// Value constraints applied before anything reaches the Keychain or UserDefaults.
///
/// Without these, a mistyped value is stored happily and only surfaces later as an opaque
/// HTTP failure from a completely different command — with nothing pointing back at the
/// `config write` that caused it.
enum ConfigValue {
    /// Stated in the README, CLAUDE.md and docs/design.md; now also enforced.
    static let apiKeyLength = 32

    /// The keys ``validated(_:for:)`` actually checks. `configItems` is the list of keys
    /// that *exist*; this is the list that gets validated, and `ConfigValidationTests`
    /// asserts the two are identical — so adding a third config key fails a test rather
    /// than silently acquiring no validation.
    static let validatedKeys: Set<String> = ["api-key", "protect-host"]

    /// Returns the value to store, or throws describing the expected shape.
    ///
    /// Surrounding whitespace is stripped rather than rejected: a key pasted from a web UI
    /// often carries a trailing newline, and storing that produces an authentication
    /// failure whose cause is invisible in every subsequent error message.
    static func validated(_ raw: String, for key: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        switch key {
        case "api-key":
            // Report the length, never the value. `config read` deliberately obfuscates
            // this secret, so an error message must not be the thing that prints it.
            guard value.count == apiKeyLength else {
                throw ValidationError(
                    "api-key must be exactly \(apiKeyLength) characters; got \(value.count). "
                        + "Generate one in Protect → Settings → Control Plane → Integrations.")
            }

        case "protect-host":
            guard !value.isEmpty else {
                throw ValidationError(
                    "protect-host must not be empty. Give a hostname or IP address, "
                        + "e.g. unvr.local or 192.168.1.99.")
            }
            guard !value.contains(where: \.isWhitespace) else {
                throw ValidationError(
                    "protect-host must not contain whitespace. Give a hostname or IP "
                        + "address, e.g. unvr.local or 192.168.1.99.")
            }

        default:
            // Unreachable via the CLI: `Write.run()` rejects unknown keys before calling
            // this. Kept total so the switch compiles, and covered by the
            // validatedKeys/configItems agreement test rather than by a fatalError.
            break
        }

        return value
    }
}

struct Write: AsyncParsableCommand {
    @Argument(help: "the key name:  protect-host or api-key")
    var key: String

    @Argument(help: "the value: a hostname or IP, or a \(ConfigValue.apiKeyLength)-character API key")
    var valueToWrite: String

    func run() async throws {
        guard let item = configItems[key] else {
            throw ValidationError("Unknown config key: \(key)")
        }

        // Validate before writing: a rejected value must leave the stored one untouched.
        try item.write(ConfigValue.validated(valueToWrite, for: key))
    }
}

struct Read: AsyncParsableCommand {
    @Argument(help: "optional key name to read:  protect-host or api-key")
    var key: String?

    func run() async throws {
        if let key = key {
            guard let item = configItems[key] else {
                throw ValidationError("Unknown config key: \(key)")
            }

            // Print the item, never the raw value. `ConfigStorable.description` is what
            // obfuscates a secret — printing `try item.read()` directly emitted the API
            // key in cleartext, which the no-argument branch below never did.
            guard try item.read() != nil else {
                print("No value set for \(key)")
                return
            }
            print(item.description)
        } else {
            for (_, item) in configItems.sorted(by: { $0.key < $1.key }) {
                print(item.description)
            }
        }
    }
}

struct Config: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage tool configuration (protect host, api key) and defaults",
        subcommands: [Write.self, Read.self]
    )
}
