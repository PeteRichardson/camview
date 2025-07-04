# camview - Control a Unifi Viewport from the command line

### Features
* switch Liveviews
* list Viewports, Liveviews, or Cameras

### Usage
```
USAGE: cam-view <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  list                    Show a list of liveviews, viewports or cameras
  show                    Set a Liveview for a Viewport
  snapshot                Capture a snapshot of a camera's current view
  config                  Manage tool configuration (protect host, api key) and defaults
```

#### Switching Liveviews:
SWITCHING LIVEVIEWS:
You can switch to an available Liveview by passing the Liveview name on the cmd line.
Names are case-INsensitive.
e.g.
camview show Driveway

If you don't pass in a Liveview name, it will try a liveview called "Default"

NOTE: Currently, camview changes the liveview on only the *first* Viewport
returned by the Protect API.   This will be fixed in a future version.

#### Listing Viewports, Liveviews and Cameras:
* You can list available Viewports with `camview list viewports`
* You can list available Liveviews with `camview list liveviews` (or just `camview list`)
* You can list available Cameras with `camview list cameras`
* You can get more data in csv format by adding `-f csv`.  e.g.  `camview list cameras -f csv`

### Configuration:
Camview requires a ~/.config/camview.json file that contains your Unifi Protect host IP or DNS name.  Like this:
```json
{
	"unifi" : {
		"protect" : {
			"api": {
				"host": "192.168.1.1",
			}
		}
	}
}
```

### Authentication
You also need to provide your Unifi Protect API Key (a 32 character string which you can generate in Protect -> Settings -> Control Plane -> Integrations).
camview has the `config set` subcommand to store the API key in the macOS keychain, where it will be found for future camview invocations.  For example:

```
camview config set --protect-api-key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
camview config dump
```

### Elgato Stream Deck
To change the live view on your Viewport by pushing a button on an Elgato Stream Deck, you can wrap the cli "camview show" call in a mac app using Automator.   Or, you can use the code in the Streamdeck Extras folder to quickly generate smaller, faster apps.   For more info, see [this readme](streamdeck%20extras/README.md).
