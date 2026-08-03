//
//  HelpTextTests.swift
//  CamviewCLITests
//

import ArgumentParser
import Testing

@testable import camview

/// The root `discussion` was a 78-line second copy of the README, and it had already
/// drifted from it: it named `list liveviews` as the source of the default viewport
/// (it's `list viewports`), and after PR #50 it still claimed snapshot output could not
/// go to a file. Nothing linked the two copies, so nothing caught either.
///
/// These pin the shape that prevents a third copy: the root help is an orientation block
/// that points at the README, and per-subcommand help is where detail lives.
@Suite("help text")
struct HelpTextTests {

    // MARK: the root discussion

    /// A line count rather than a content assertion, deliberately. What went wrong wasn't
    /// any one sentence — it was that the block was large enough to be a second manual
    /// and drift from the first unnoticed.
    @Test("the root discussion stays an orientation block, not a second README")
    func rootDiscussionIsShort() {
        let lines = CamView.configuration.discussion
            .split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count <= 20)  // it was 78
    }

    @Test("the root discussion points at the README instead of restating it")
    func rootDiscussionPointsAtReadme() {
        #expect(CamView.configuration.discussion.contains("README"))
    }

    @Test("the root discussion no longer names `list liveviews` as the viewport source")
    func rootDiscussionDropsStaleViewportCommand() {
        // The specific drift #13 cites. Implied by the length cap today, but this is what
        // fires if the sentence is ever pasted back.
        #expect(!CamView.configuration.discussion.contains("list liveviews"))
    }

    // MARK: per-subcommand help

    @Test("snapshot carries the detail the root discussion no longer does")
    func snapshotHasItsOwnDiscussion() {
        #expect(!Snapshot.configuration.discussion.isEmpty)
    }

    @Test("snapshot's help explains where the image actually goes")
    func snapshotHelpExplainsDestinations() {
        // This used to live only in the root discussion, sixty lines below anything else
        // about snapshots — which is how it came to still claim output "goes to the
        // terminal or the clipboard, not to a file" a full release after PR #50 made the
        // redirect case work. The subcommand with the behaviour is the one that documents
        // it, so there is only one copy to keep true.
        let discussion = Snapshot.configuration.discussion
        #expect(discussion.contains("clipboard"))
        #expect(discussion.contains(".jpg"))
    }
}
