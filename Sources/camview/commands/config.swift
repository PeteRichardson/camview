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

/// The `config write` end of validation: normalize the argument, then apply the shared
/// rules in ``ConfigRule`` and report failures the way ArgumentParser reports a bad
/// argument.
///
/// The rules themselves live in `CamviewCore` because this is only one of three documented
/// ways to set these values — see ``ConfigRule`` — and `Configuration.init()` applies the
/// same rules to whatever is already stored.
enum ConfigValue {
    /// Returns the value to store, or throws describing the expected shape.
    ///
    /// Surrounding whitespace is stripped rather than rejected, which is an affordance
    /// specific to typed and pasted input: a key copied from a web UI often carries a
    /// trailing newline, and storing that produces an authentication failure whose cause
    /// is invisible in every later error message. ``ConfigRule`` itself stays strict, so a
    /// value that reached storage by another route is reported rather than silently fixed.
    static func validated(_ raw: String, for key: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let reason = ConfigRule.rejection(for: value, key: key) {
            throw ValidationError(reason)
        }

        return value
    }
}

struct Write: AsyncParsableCommand {
    @Argument(help: "the key name:  protect-host or api-key")
    var key: String

    @Argument(help: "the value: a hostname or IP, or a \(ConfigRule.apiKeyLength)-character API key")
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
