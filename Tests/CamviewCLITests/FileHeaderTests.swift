//
//  FileHeaderTests.swift
//  CamviewCLITests
//

import Foundation
import Testing

/// Every Swift file here opens with Xcode's boilerplate header naming the file. The name
/// is written once, at `File > New`, and never updated — so a rename silently leaves the
/// header pointing at a file that no longer exists. `snapshot.swift` claimed to be
/// `Show.swift` and `camview.swift` claimed to be `main.swift`, both for months.
///
/// The comment is worth keeping or worth deleting, but it isn't worth keeping *wrong*:
/// a header naming another real file in the same directory actively misleads anyone
/// skimming, which is the one job it has.
///
/// This walks the source tree rather than listing files, so a new file is covered the day
/// it's added without editing this test.
@Suite("source file headers")
struct FileHeaderTests {

    /// The repo root, derived from this file's own location:
    /// `<root>/Tests/CamviewCLITests/FileHeaderTests.swift`.
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CamviewCLITests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // <root>

    /// `camgui/` is deliberately out of scope. `CameraListView.swift`'s header says
    /// `CameraList.swift`, which is the same defect — but it's tracked as #31 along with
    /// the type rename that goes with it, and asserting on it here would make this suite
    /// fail until that lands.
    static let scannedDirectories = ["Sources", "Tests"]

    static func swiftFiles() -> [URL] {
        scannedDirectories.flatMap { directory -> [URL] in
            let root = repoRoot.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil)
            else { return [] }
            return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        }
    }

    @Test("the tree is actually being scanned")
    func scanFindsFiles() throws {
        // Without this, a wrong `repoRoot` would silently scan nothing and the test below
        // would pass by vacuity — the exact failure mode a filesystem-walking test has.
        let files = Self.swiftFiles()
        #expect(files.count > 10, "expected to find the source tree at \(Self.repoRoot.path)")
    }

    @Test("every header names the file it is actually in")
    func headersNameTheirOwnFile() throws {
        for file in Self.swiftFiles() {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)

            // The convention is `//\n//  <FileName>\n//  <module>\n//`. A file that
            // doesn't follow it isn't a failure — deleting the header is a valid choice,
            // and this suite only cares that a header which *is* present tells the truth.
            guard lines.count >= 2, lines[0] == "//" else { continue }
            let second = lines[1].trimmingCharacters(in: .whitespaces)
            guard second.hasPrefix("//"), second.hasSuffix(".swift") else { continue }

            let claimed = second.dropFirst(2).trimmingCharacters(in: .whitespaces)
            #expect(
                claimed == file.lastPathComponent,
                "\(file.lastPathComponent) has a header claiming to be \(claimed)")
        }
    }
}
