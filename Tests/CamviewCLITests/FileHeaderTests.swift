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

    /// `camgui/` was out of scope when this suite was written: `CameraListView.swift`'s
    /// header said `CameraList.swift`, which is the same defect, but it was tracked as #31
    /// along with the type rename that belongs with it. #31 fixed it, so the directory is
    /// in scope now — which was the whole point of leaving the note.
    static let scannedDirectories = ["Sources", "Tests", "camgui"]

    /// Build output, which contains source this repo does not own and cannot fix.
    ///
    /// `camgui/Build` is the one that forced this: Xcode puts SPM checkouts under it, so
    /// scanning `camgui/` naively finds `Protect`'s sources and reports six failures for
    /// headers in someone else's package (`camera.swift` in `Camera.swift`, and so on).
    /// Worse, it does that only on a machine where camgui has been built — a clean
    /// checkout passes, so the suite would have looked fine everywhere except a
    /// developer's laptop.
    ///
    /// `camgui/project.yml` excludes the same directory for a closely related reason, and
    /// its comment records that the recursive-glob version of this mistake is what made
    /// the `sources:` list explicit in the first place.
    static let ignoredDirectories: Set<String> = ["Build", ".build", "DerivedData"]

    static func swiftFiles() -> [URL] {
        var found: [URL] = []
        for directory in scannedDirectories {
            let root = repoRoot.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.isDirectoryKey])
            else { continue }
            for case let url as URL in walker {
                let isDirectory =
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                // Pruning the walk rather than filtering the results: matching on full
                // path components would also fire if the repo itself lived under a
                // directory called `Build`, and would then silently scan nothing.
                if isDirectory, ignoredDirectories.contains(url.lastPathComponent) {
                    walker.skipDescendants()
                    continue
                }
                if url.pathExtension == "swift" { found.append(url) }
            }
        }
        return found
    }

    @Test("the tree is actually being scanned")
    func scanFindsFiles() throws {
        // Without this, a wrong `repoRoot` would silently scan nothing and the test below
        // would pass by vacuity — the exact failure mode a filesystem-walking test has.
        let files = Self.swiftFiles()
        #expect(files.count > 10, "expected to find the source tree at \(Self.repoRoot.path)")
    }

    @Test("build output is not scanned")
    func buildOutputIsExcluded() {
        // Only meaningful on a machine where camgui has actually been built — which is
        // exactly the machine where the omission would bite, and never CI.
        let leaked = Self.swiftFiles().filter { url in
            url.pathComponents.contains { Self.ignoredDirectories.contains($0) }
        }
        #expect(leaked.isEmpty, "scanned build output: \(leaked.map(\.lastPathComponent))")
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
