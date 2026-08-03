//
//  NameMatchingTests.swift
//  CamviewCLITests
//

import Testing

@testable import camview

/// Case-insensitive name resolution is what makes the Stream Deck launchers work: each
/// one passes its own lowercased executable name (`driveway180`) and expects to find the
/// liveview `Driveway180`. If this regressed, twelve buttons would stop working at once.
@Suite("Case-insensitive name matching")
struct NameMatchingTests {

    let items = [FakeItem("Driveway180"), FakeItem("FrontDoor"), FakeItem("KatsAlley")]

    @Test("an exact name matches")
    func exact() {
        #expect(items.firstMatching(name: "FrontDoor")?.name == "FrontDoor")
    }

    @Test("a lowercased name matches — the Stream Deck launcher case")
    func lowercased() {
        #expect(items.firstMatching(name: "driveway180")?.name == "Driveway180")
    }

    @Test("an uppercased name matches")
    func uppercased() {
        #expect(items.firstMatching(name: "KATSALLEY")?.name == "KatsAlley")
    }

    @Test("an unknown name matches nothing")
    func noMatch() {
        #expect(items.firstMatching(name: "Basement") == nil)
    }

    @Test("no partial matching — a prefix is not a match")
    func noPartialMatch() {
        // Substring matching would make `camview show front` ambiguous the moment a
        // second liveview started with the same word.
        #expect(items.firstMatching(name: "Front") == nil)
    }

    @Test("an empty collection matches nothing")
    func empty() {
        #expect([FakeItem]().firstMatching(name: "FrontDoor") == nil)
    }

    @Test("names differing only in case resolve to the first, not an arbitrary one")
    func firstWins() {
        // Protect doesn't stop you naming two liveviews `Deck` and `deck`. Whichever
        // rule applies, it has to be deterministic.
        let duplicates = [FakeItem("Deck", id: "1"), FakeItem("deck", id: "2")]
        #expect(duplicates.firstMatching(name: "DECK")?.id == "1")
    }
}
