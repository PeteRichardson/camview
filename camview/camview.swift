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

CONFIGURATION:
Camview requires a ~/.config/camview.json file that contains your Unifi Protect host IP or DNS name.  Like this:
{
    "unifi" : {
        "protect" : {
            "api": {
                "host": "192.168.1.1",
            }
        }
    }
}

AUTHENTICATION
You also need to provide your Unifi Protect API Key (a 32 character string which you can generate in Protect -> Settings -> Control Plane -> Integrations).
camview has the `config set` subcommand to store the API key in the macOS keychain, where it will be found for future camview invocations.  For example:

```
camview config set --protect-api-key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
camview config dump
```

ELGATO STREAM DECK:
To change the live view on your Viewport by pushing a button on an Elgato Stream Deck, you can wrap the cli "camview show" call in a mac app using Automator.   Or, you can use the code in the Streamdeck Extras folder to quickly generate smaller, faster apps.
""",
        subcommands: [List.self, Show.self, Snapshot.self, Config.self],

)

}


