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
You can switch to an available Liveview by passing the Liveview name on the cmd line. Names are case-INsensitive.
e.g. `camview show Driveway`

If you don't give a Liveview name, it will try a liveview called "Default"

NOTE: Currently, camview changes the liveview on only the *first* Viewport
returned by the Protect API.   This will be fixed in a future version.

LISTING VIEWPORTS, LIVEVIEWS AND CAMERAS:
* You can list available Viewports with `camview list viewports`
* You can list available Liveviews with `camview list liveviews` (or just `camview list`)
* You can list available Cameras with `camview list cameras`
* You can get more data in csv format by adding `-f csv`.  For example: `camview list cameras -f csv`

CONFIGURATION:
Camview needs two configuration strings:
1. your Unifi Protect host IP or DNS name.  For example  192.168.1.1 or udm.local
2. your Unifi Protect API Key  (a 32 character string which you can generate in Protect -> Settings -> Control Plane -> Integrations)

Use the config write subcommand to store them where camview can find them.
- The API Key is stored securely in the macOS keychain as an "application password" under "com.peterichardson.camview"
- The Protect host is stored in user preferences in domain "com.peterichardson.camview", key "protect-host"

camview config write api-key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
camview config write protect-host 192.168.1.1
camview config read


You can also use built in macOS tools (security and defaults) to set and validate these items:


# Get API Key
security find-generic-password -a api-key -s com.peterichardson.camview -w

# Set API Key
security add-generic-password -a dummy -s com.peterichardson.camview -w XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Get Protect Host
defaults read com.peterichardson.camview protect-host

# Set Protect Host
defaults write com.peterichardson.camview protect-host 192.168.1.1


ELGATO STREAM DECK:
To change the live view on your Viewport by pushing a button on an Elgato Stream Deck, you can wrap the cli "camview show" call in a mac app using Automator.   Or, you can use the code in the Streamdeck Extras folder to quickly generate smaller, faster apps.
""",
        subcommands: [List.self, Show.self, Snapshot.self, Config.self],

)

}


