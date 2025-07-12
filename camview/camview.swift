//
//  main.swift
//  camview
//
//  Created by Peter Richardson on 6/24/25.
//

import Foundation
import ArgumentParser

@main
struct CamView : AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "camview",
        abstract: "CLI to control a Unifi Protect Viewport.",
        discussion: """

GETTING STARTED:
1. Generate an API Key to allow access to the Protect API.
You can generate an API key from the UniFi Protect web interface by navigating to Settings → Control Plane → Integrations.
The API Key is a 32 character string

2. Run the following commands:
camview config write api-key <your-API-Key>
camview config write protect-host <your-Unifi-Protect-web-interface-hostname-or-IP-Address>

3. Confirm that they are set correctly by running
camview config read

4. Try out camview!
camview list cameras
camview list viewports
camview list liveviews
camview show Backyard MyViewport   # assumes you have a camera called Backyard and a viewport named MyViewport
camview snapshot Backyard   # if your terminal supports iTerm image protocal (e.g. iTerm, Warp, Wezterm)


----------------------------------------------------------------
SWITCHING LIVEVIEWS:
You can switch to an available Liveview by passing the Liveview name on the cmd line. Names are case-INsensitive.
e.g. `camview show Driveway`

If you don't give a Liveview name, it will try a liveview called "Default"

By default, camview will switch the liveview on the first viewport returned by the list liveviews command.

LISTING VIEWPORTS, LIVEVIEWS AND CAMERAS:
* You can list available Viewports with `camview list viewports`
* You can list available Liveviews with `camview list liveviews` (or just `camview list`)
* You can list available Cameras with `camview list cameras`
* You can get more data in csv format by adding `-f csv`.  For example: `camview list cameras -f csv`

GETTING CAMERA SNAPSHOTS:
The `camview snapshot [-c | --clipboard ] <camera-name>` command will capture a snapshot from the specified camera and write it to the clipboard (with -c) or to the terminal (without -c).

- It's a static snapshot, not a streaming video.
- It sends output to the terminal or the clipboard, not to a file
- It uses the iTerm image protocol, not Kitty
- Not all Mac terminal programs can show images inline.   I've tested that it works in iTerm2, Warp and Wezterm.

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


Of course, you can also use built in macOS tools (security and defaults) to set and validate these items:

# Get API Key
security find-generic-password -a api-key -s com.peterichardson.camview -w

# Set API Key
security add-generic-password -a api-key -s com.peterichardson.camview -w XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Get Protect Host
defaults read com.peterichardson.camview protect-host

# Set Protect Host
defaults write com.peterichardson.camview protect-host 192.168.1.1


EXTRAS:
ELGATO STREAM DECK
To change the live view on your Viewport by pushing a button on an Elgato Stream Deck, you can wrap the cli "camview show" call in a mac app using Automator.   Or, you can use the code in the Streamdeck Extras folder to quickly generate smaller, faster apps.
""",
        subcommands: [List.self, Show.self, Snapshot.self, Config.self],

)

}


