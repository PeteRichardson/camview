//
//  camview.swift
//  camview
//
//  Created by Peter Richardson on 6/24/25.
//

import Foundation
import ArgumentParser

@main
struct CamView : AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "camview",
        abstract: "CLI to control a Unifi Protect Viewport.",
        discussion: """

FIRST RUN:
  camview config write api-key <32-character-key>
  camview config write protect-host <hostname-or-IP>
  camview config read                 # confirm; the key is printed obfuscated

  The API key comes from the Protect web interface, under
  Settings -> Control Plane -> Integrations.

THEN:
  camview list cameras                # also: viewports, liveviews
  camview show Driveway               # switch a viewport to a liveview
  camview snapshot Backyard           # capture a still

Every subcommand documents its own options: `camview <subcommand> --help`.
Camera, viewport and liveview names are matched case-insensitively.

Full documentation — setup, where config is stored, which terminals can draw a
snapshot inline, and the Stream Deck launchers — is in the README:
https://github.com/PeteRichardson/camview
""",
        subcommands: [List.self, Show.self, Snapshot.self, Config.self],

)

}


