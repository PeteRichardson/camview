# camview - Control a Unifi Viewport from the command line

### Features
* switch Liveviews on Viewports
* list Viewports, Liveviews, or Cameras
* Display a snapshot of a camera's current view (requires iTerm2 or Warp)

### Usage
```
USAGE: camview <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  show [liveview] [viewport]               Set a Liveview for a Viewport
  snapshot (camera)                        Display a snapshot of a camera's current view (requires iTerm2 or Warp)
  list (cameras | viewports | liveviews)   Show a list of liveviews, viewports or cameras
  config (read | write)                    Manage tool configuration (protect host, api key)
```

----
#### Getting Started:
1 . Generate an API Key to allow access to the Protect API.
You can generate an API key from the UniFi Protect web interface by navigating to Settings → Control Plane → Integrations.
The API Key is a 32 character string

2 . Run the following commands to set the API key and host:
```
camview config write api-key <your-API-Key>
camview config write protect-host <your-Unifi-Protect-web-interface-hostname-or-IP-Address>
```

3 . Confirm that they are set correctly by running
```
camview config read  # Note: the api-key will be slightly obfuscated
```

4 . Try out camview!
```
camview list cameras
camview list viewports
camview list liveviews
camview show Backyard MyViewport   # assumes you have a camera called Backyard and a viewport named MyViewport
camview snapshot Backyard   # if you're running iTerm2 or Warp
```

----

### Switching Liveviews
You can tell a viewport to switch to a specific Liveview by passing the Liveview name and Viewport name on the cmd line. Names are case-INsensitive.
e.g. `camview show Driveway MyViewport`

If you don't give a Viewport name, it will use the first viewport returned by the `camview list viewports` command
e.g. `camview show Backyard`

If you don't give either a Liveview name or a Viewport name it will, it will try a liveview called "Default" on the first viewport returned by `camview list viewports`
e.g. `camview show`

Note: You can't give a viewport name without a liveview name.  camview will assume it's a liveview name, and may or may not do what you want.
e.g. `camview show MyViewport      # Uh-oh! Tries to find a Liveview called MyViewport!!)`


#### Listing Viewports, Liveviews and Cameras
* You can list available Viewports with `camview list viewports`
* You can list available Liveviews with `camview list liveviews` (or just `camview list`)
* You can list available Cameras with `camview list cameras`
* You can get more data in csv format by adding `-f csv`.  For example: `camview list cameras -f csv`

Note: The listings are minimal and ugly.  There is a lot that can be improved in future versions.

#### Getting Camera Snapshots
Some Mac Terminal replacements (e.g. iTerm2 and Warp) can show images inline.   camview has a Snapshot subcommand that captures a snapshot from the specified camera and displays it inline in the terminal.

- It's a static snapshot, not a streaming video.
- It sends output to the terminal, not to a file or the clipboard (yet)
- It uses the iTerm image protocol, not Kitty
- I've only tested it in iTerm2 and Warp

#### Configuration Details
Camview needs two configuration strings:
1. your Unifi Protect host IP or DNS name.  For example  `192.168.1.1` or `udm.local`
2. your Unifi Protect API Key  (a 32 character string which you can generate in Protect -> Settings -> Control Plane -> Integrations)

Use the config write subcommand to store them where camview can find them.
- The API Key is stored securely in the macOS keychain as an `application password` under `com.peterichardson.camview`
- The Protect host is stored in user preferences in domain `com.peterichardson.camview` under the key `protect-host`
```
camview config write api-key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
camview config write protect-host 192.168.1.1
camview config read
```

Of course, you can also use built in macOS tools (`security` and `defaults`) to set and validate these items:

```
# Get API Key
security find-generic-password -a api-key -s com.peterichardson.camview -w

# Set API Key
security add-generic-password -a api-key -s com.peterichardson.camview -w XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Get Protect Host
defaults read com.peterichardson.camview protect-host

# Set Protect Host
defaults write com.peterichardson.camview protect-host 192.168.1.1
```

## Extras
### Elgato Stream Deck
To change the live view on your Viewport by pushing a button on an Elgato Stream Deck, you can wrap the cli "camview show" call in a mac app using Automator.   Or, you can use the code in the Streamdeck Extras folder to quickly generate smaller, faster apps.   For more info, see [this readme](streamdeck%20extras/README.md).
