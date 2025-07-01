//
//  config.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser



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
        abstract: "Set tool configuration (protect host, api key) and defaults",
    )
    
    func run() async throws {
        print("# TODO: update one of the config values, esp. default viewport")
    }
}


struct ConfigDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump tool configuration (protect host, api key) and defaults",
    )
    
    func run() async throws {
        print("# TODO:  Dump Config.   Make sure to obfuscate the API Key")
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
        let apiKey: String
    }

    struct Protect: Codable {
        let api: ProtectAPI
    }

    struct Unifi: Codable {
        let protect: Protect
    }

    let unifi: Unifi
    
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
        } catch  {
            return nil
        }
    }
}
