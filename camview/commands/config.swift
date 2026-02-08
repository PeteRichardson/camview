//
//  config.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import ArgumentParser
import Foundation
import Security

enum ConfigError: Error, CustomStringConvertible {
    case unableToLoad(reason: String)
    case unknown(Error)

    var description: String {
        switch self {
        case .unableToLoad(let reason):
            return "Unable to load config: \(reason)"
        case .unknown(let error):
            return "Unknwon error: \(error)"
        }
    }
}

let configItems: [String: ConfigStorable] = [
    "protect-host": ConfigItem(name: "protect-host", defaultsKey: "protect-host"),
    "api-key": SecureConfigItem(name: "api-key", keychainKey: "api-key"),
]

protocol ConfigStorable: CustomStringConvertible {
    var name: String { get }
    func read() throws -> String?
    func write(_ value: String) throws
    var description: String { get }
}

extension ConfigStorable {
    var description: String {
        "\(name) = \(try! read() ?? "(not set)")"
    }
}

struct ConfigItem: ConfigStorable {
    let suiteName = "group.com.peterichardson.camview"

    let name: String
    let defaultsKey: String
    var description: String {
        "\(name) = \(try! read() ?? "(not set)")"
    }

    func read() throws -> String? {
        let defaults = UserDefaults(suiteName: suiteName)!
        let result = defaults.string(forKey: defaultsKey)
        return result
    }

    func write(_ value: String) throws {
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults.set(value, forKey: defaultsKey)
    }
}

struct SecureConfigItem: ConfigStorable {
    let name: String
    let keychainKey: String

    func read() throws -> String? {
        try Keychain.read(keychainKey)
    }

    var description: String {
        let value = try! read() ?? "(not set)"
        return "\(String(value.prefix(6)))....................\(String(value.suffix(6)))"
    }

    func write(_ value: String) throws {
        try Keychain.write(value, for: keychainKey)
    }
}

enum Keychain {
    static let service = "com.peterichardson.camview"

    static func write(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "Keychain", code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Unable to save API key"])
        }
    }

    static func read(_ key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8)
        else {
            throw NSError(
                domain: "Keychain", code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "API key not found in Keychain"])
        }
        return key
    }
}

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
