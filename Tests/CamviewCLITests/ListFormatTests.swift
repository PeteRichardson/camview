//
//  ListFormatTests.swift
//  CamviewCLITests
//

import ArgumentParser
import Testing

@testable import camview

/// `--format` and the `list` object argument were both free `String`s once, so an
/// unrecognised value fell through to the summary branch and exited 0 — a typo silently
/// produced the wrong output. These pin the enums that replaced them.
@Suite("list argument parsing")
struct ListArgumentTests {

    @Test("every documented list object parses")
    func objectsParse() {
        #expect(ListObject(argument: "liveviews") == .liveviews)
        #expect(ListObject(argument: "viewports") == .viewports)
        #expect(ListObject(argument: "cameras") == .cameras)
    }

    @Test("an unknown list object is rejected rather than defaulted")
    func unknownObjectRejected() {
        #expect(ListObject(argument: "camera") == nil)
        #expect(ListObject(argument: "") == nil)
    }

    @Test("every documented format parses")
    func formatsParse() {
        #expect(OutputFormat(argument: "summary") == .summary)
        #expect(OutputFormat(argument: "csv") == .csv)
    }

    @Test("an unknown format is rejected rather than falling through to summary")
    func unknownFormatRejected() {
        #expect(OutputFormat(argument: "json") == nil)
        #expect(OutputFormat(argument: "CSV") == nil)  // ArgumentParser is case-sensitive here
    }

    @Test("allCases drives the help text, so it must list every case")
    func allCasesComplete() {
        #expect(ListObject.allCases.map(\.rawValue) == ["liveviews", "viewports", "cameras"])
        #expect(OutputFormat.allCases.map(\.rawValue) == ["summary", "csv"])
    }
}

/// Format dispatch. The header is the part worth pinning: it belongs to csv only, and it
/// is emitted even when there are no rows, so `-f csv` piped into a parser always produces
/// a well-formed document.
@Suite("list output rendering")
struct ListRenderingTests {

    let items = [FakeItem("Deck", id: "aaa"), FakeItem("FirePit", id: "bbb")]

    @Test("summary emits one line per item and no header")
    func summaryHasNoHeader() {
        let lines = renderedLines(items, format: .summary)
        #expect(lines.count == 2)
        #expect(lines[0] == "Deck [aaa]")
        #expect(lines[1] == "FirePit [bbb]")
    }

    @Test("csv emits a header followed by one row per item")
    func csvHasHeader() {
        let lines = renderedLines(items, format: .csv)
        #expect(lines.count == 3)
        #expect(lines[0] == "name,id")
        #expect(lines[1] == "Deck,aaa")
        #expect(lines[2] == "FirePit,bbb")
    }

    @Test("csv still emits its header when there is nothing to list")
    func csvHeaderWithNoRows() {
        #expect(renderedLines([FakeItem](), format: .csv) == ["name,id"])
    }

    @Test("summary of nothing is nothing")
    func emptySummary() {
        #expect(renderedLines([FakeItem](), format: .summary).isEmpty)
    }
}
