//
//  NameMatching.swift
//  camview
//

import Protect

extension Collection where Element: ProtectFetchable {
    /// The first element whose name matches `name`, ignoring case.
    ///
    /// Camera, viewport and liveview names are matched case-insensitively throughout the
    /// CLI — `camview show driveway180` is meant to find the liveview `Driveway180`. That
    /// rule used to be re-implemented inline at each call site, which is how it ends up
    /// applied in one place and forgotten in another.
    ///
    /// Ties go to the first match in the collection: Protect does not prevent two
    /// liveviews differing only in case, and picking arbitrarily would make the CLI
    /// non-deterministic.
    func firstMatching(name: String) -> Element? {
        let target = name.lowercased()
        return first { $0.name.lowercased() == target }
    }
}
