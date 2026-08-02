//
//  config.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import ArgumentParser
import Foundation
import SimpleConfig

let configItems: [String: any ConfigStorable] = [
    "api-key": SecureConfigItem(
        service: "com.peterichardson.camview",
        key: "api-key"),
    "protect-host": ConfigItem(
        suiteName: "group.com.peterichardson.camview",
        key: "protect-host"),

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
            for item in configItems.sorted(by: { $0.key < $1.key}) {
                let value = item.value
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

    init() throws {
        guard let apiKey = try configItems["api-key"]?.read() else {
            throw ValidationError("api-key not configured. Run: camview config write api-key <key>")
        }
        self.apiKey = apiKey
        if let host = try configItems["protect-host"]?.read() {
            self.host = host
        }
    }
}
