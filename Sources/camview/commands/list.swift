//
//  List.swift
//  camview
//
//  Created by Peter Richardson on 7/1/25.
//

import Foundation
import ArgumentParser
import CamviewCore
import OSLog
import Protect

/// What `camview list` can enumerate.
///
/// An enum rather than a free `String` so ArgumentParser rejects an unknown value and
/// lists the valid ones, instead of the command hand-rolling that check at runtime.
enum ListObject: String, ExpressibleByArgument, CaseIterable {
    case liveviews
    case viewports
    case cameras
}

/// How each item is rendered.
///
/// Also an enum: a free `String` meant an unrecognised `--format` fell through to the
/// summary branch and exited 0, so a typo silently produced the wrong output.
enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case summary
    case csv
}

/// The exact lines `list` would print, as data.
///
/// Split out from ``list(_:format:)`` so the format dispatch can be asserted directly.
/// While this logic printed as it went, testing it meant capturing stdout, which is enough
/// friction that it simply went untested.
func renderedLines<T: ProtectFetchable>(_ array: [T], format: OutputFormat) -> [String] {
    // HEADER — csv only. A summary listing has no header line.
    var lines: [String] = format == .csv ? [T.csvHeader] : []

    // LIST ITEMS
    lines += array.map { format == .csv ? $0.csvDescription() : $0.description }

    // FOOTER
    // None yet.
    return lines
}

func list<T: ProtectFetchable>(_ array: [T], format: OutputFormat = .summary) {
    for line in renderedLines(array, format: format) {
        print(line)
    }
}

struct List: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Show a list of liveviews, viewports or cameras",
    )

    @Argument(help: "Type of object to list")
    var object: ListObject = .liveviews

    @Option(name: .shortAndLong, help: "Format to use")
    var format: OutputFormat = .summary

    func run() async throws {
        let log = OSLog(subsystem: "com.peterichardson.camview", category: .pointsOfInterest)
        os_signpost(.begin, log: log, name: "List", "%{public}s", "Fetching data")
        // `defer` so the interval closes on the throwing paths too, not just success.
        defer { os_signpost(.end, log: log, name: "List", "%{public}s", "Finished") }

        let config = try Configuration()

        let protect = ProtectService(host: config.host, apiKey: config.apiKey)

        switch object {
        case .liveviews:
            try await list(protect.liveviews(), format: format)
        case .viewports:
            try await list(protect.viewports(), format: format)
        case .cameras:
            try await list(protect.cameras(), format: format)
        }
    }
}
