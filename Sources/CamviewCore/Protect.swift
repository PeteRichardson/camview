//
//  Protect.swift
//  CamviewCore
//

/// Re-exports `Protect` to anything importing `CamviewCore`.
///
/// `CamviewCore` doesn't use `Protect` itself. This exists so the version is pinned in
/// exactly one place. Before it, `camgui` declared its own `Protect` package in
/// `camgui/project.yml` with a second `minorVersion`, and nothing kept the two in
/// agreement — camgui resolves its own copy under `camgui/Build/…/SourcePackages`, so the
/// CLI and the GUI could build against different versions of the same API with no error
/// anywhere.
///
/// `@_exported` is underscored and therefore not formally guaranteed, which is the cost of
/// this approach. The alternative — leaving both pins in place and documenting them as a
/// pair that must be edited together — relies on a person remembering, which is what
/// produced the drift being fixed.
@_exported import Protect
