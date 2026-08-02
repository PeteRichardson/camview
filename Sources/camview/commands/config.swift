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

struct Write: AsyncParsableCommand {
    @Argument(help: "the key name:  protect-host or api-key")
    var key: String

    @Argument(help: "the key value: e.g. \"192.168.1.1\" or \"XXXXXXXXXXXXXXXXXXXXX\"")
    var valueToWrite: String

    func run() async throws {
        guard let item = configItems[key] else {
            throw ValidationError("Unknown config key: \(key)")
        }

        try item.write(valueToWrite)
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
