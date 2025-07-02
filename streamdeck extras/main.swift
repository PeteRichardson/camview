import Foundation
//import os

//let log = Logger(subsystem: "com.peterichardson.minimal", category: "camview")
let process = Process()
process.executableURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/camview")
process.arguments = ["show", target]
process.standardOutput = nil
process.standardError = nil
process.standardInput = nil

do {
    //log.log("> \(process.executableURL?.path ?? "<nil>", privacy: .public) \(process.arguments!.joined(separator: " "), privacy: .public)")
    try process.run()
    // Don't wait or print anything
} catch {
    //log.error("Failed to launch \(process.executableURL?.path ?? "<nil>", privacy: .public): \(error.localizedDescription, privacy: .public)")
}