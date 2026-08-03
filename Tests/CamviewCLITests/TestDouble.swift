//
//  TestDouble.swift
//  CamviewCLITests
//

import Protect

/// A minimal `ProtectFetchable` so the rendering and matching tests don't need a live
/// controller. `description`, `<` and `==` all come from the protocol's own default
/// implementations, which is deliberate: the real types inherit those too, so a double
/// that reimplemented them would be testing itself.
struct FakeItem: ProtectFetchable {
    static let urlSuffix = "fakes"
    static let csvHeader = "name,id"

    var id: String
    var name: String

    func csvDescription() -> String { "\(name),\(id)" }
}

extension FakeItem {
    /// `Liveview` and `Viewport` both render `description` as name-then-id, so the shared
    /// default is what these tests exercise.
    init(_ name: String, id: String = "0") {
        self.init(id: id, name: name)
    }
}
