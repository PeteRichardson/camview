//
//  config.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import ArgumentParser
import Foundation
import SimpleConfig


let configItems: [String: ConfigStorable] = [
    "protect-host": ConfigItem(name: "protect-host", defaultsKey: "protect-host"),
    "api-key": SecureConfigItem(name: "api-key", keychainKey: "api-key"),
]


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

            if let value = try item.read() {
                print(value.description)
            } else {
                print("No value set for \(key)")
            }
        } else {
            for item in configItems {
                let value = item.value.description
                print(value)
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

struct Configuration {
    var host: String = "unvr.local"
    var apiKey: String = ""

    init?() {
        do {
            self.apiKey = try configItems["api-key"]!.read()!
            if let item = configItems["protect-host"], let host = try item.read() {
                self.host = host
            }
        } catch {
            print("Error! \(error)")
        }
    }
}
