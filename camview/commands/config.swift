//
//  config.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser
import Security


struct ConfigInit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a template configuration file including protect host and API key",
    )
    
    func run() async throws {
        print("# TODO: Create config from template.   Print out path.  Mabye open the editor?  Interactive query?")
    }
}

struct ConfigSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set api key in Keychain",
    )
    
    @Option(name: .shortAndLong, help: "The configuration value to set")
    var protectAPIKey: String
    
    func run() async throws {
        try Keychain.SaveApiKey(protectAPIKey)
    }
}


struct ConfigDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump obfuscated api key from Keychain",
    )
    
    func run() async throws {
        do {
            let apiKey = try Keychain.LoadApiKey()
            print("protect-api-key: \(apiKey.prefix(6))....................\(apiKey.suffix(6))")
        } catch {
            print("Could not protect-api-key from Keychain: \(error)")
        }
    }
}

struct Config: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage tool configuration (protect host, api key) and defaults",
        subcommands: [ConfigSet.self, ConfigInit.self, ConfigDump.self],
        defaultSubcommand: ConfigDump.self // optional: default to `dump` if no subcommand given
    )
}

struct Configuration: Codable {
    
    struct ProtectAPI: Codable {
        let host: String
        var apiKey: String = ""
        
        enum CodingKeys: String, CodingKey {
                case host
                // Do NOT include `apiKey` here.  That will be populated from the Keychain.
            }
    }

    struct Protect: Codable {
        var api: ProtectAPI
    }

    struct Unifi: Codable {
        var protect: Protect
    }

    var unifi: Unifi
    
    static var filepath: URL {
        return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config")
                .appendingPathComponent("camview.json")
    }
    
    init?() {
        let fileURL = Configuration.filepath
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL.standardizedFileURL)
            self = try JSONDecoder().decode(Configuration.self, from: data)
            self.unifi.protect.api.apiKey = try Keychain.LoadApiKey()
        } catch  {
            return nil
        }
    }
}


enum Keychain {
    static let account = "protect-api-key"   // the name of a single stored item.  (the key in the key-value pair)
    static let service = "com.peterichardson.camview"
    
    static func SaveApiKey(_ value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to save API key"])
        }
    }
    
    static func LoadApiKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "API key not found in Keychain"])
        }
        return key
    }
}
