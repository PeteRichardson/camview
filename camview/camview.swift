//
//  main.swift
//  camview
//
//  Created by Peter Richardson on 6/24/25.
//

import Foundation
import Logging
import ArgumentParser





@main
struct CamView : AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "CLI to control a Unifi Protect Viewport.",
        discussion: """
SWITCHING LIVEVIEWS:
You can switch to an available Liveview by passing the Liveview name on the cmd line.
Names are case-INsensitive.
e.g.
camview show Driveway

If you don't give a Liveview name, it will try a liveview called "Default"

NOTE: Currently, camview changes the liveview on only the *first* Viewport
returned by the Protect API.   This will be fixed in a future version.

LISTING VIEWPORTS, LIVEVIEWS AND CAMERAS:
* You can list available Viewports with `camview list viewports`
* You can list available Liveviews with `camview list liveviews` (or just `camview list`)
* You can list available Cameras with `camview list cameras`
* You can get more data in csv format by adding `-f csv`.  e.g.  `camview list cameras -f csv`


AUTHENTICATION:
Camview requires a ~/.config/camview.json file with Unifi Protect API credentials.
It must contain your Unifi Protect host IP or DNS name, and your API key.  Like this:
{
    "unifi" : {
        "protect" : {
            "api": {
                "host": "192.168.1.1",
                "apiKey": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
            }
        }
    }
}
""",
        subcommands: [List.self, Show.self, Snapshot.self, Config.self],

)

}


