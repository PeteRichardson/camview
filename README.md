# camview - Control a Unifi Viewport from the command line

### Features
* switch Liveviews
* list Viewports or Liveviews

### Usage
```
USAGE: cam-view [<view>] [--views] [--ports] [--csv]

ARGUMENTS:
<view>                  Name of Liveview to switch to (default: Default)

OPTIONS:
-v, --views             List Liveviews
-p, --ports             List Viewports
-c, --csv               List items as CSV
-h, --help              Show help information.
```

#### Switching Liveviews:
You can switch to an available Liveview by passing the Liveview name on the cmd line.
Names are case-INsensitive.

```
camview Driveway
```

If you don't give a Liveview name, it will try a view called "Default"

NOTE: Currently, camview changes the liveview on only the *first* Viewport
returned by the Protect API.   This will be fixed in a future version.

#### Listing Viewports and Liveviews
* You can list available Viewports with `camview -p`
* You can list available Liveviews with `camview -v`
* You can get more data in csv format by adding `-c`.  e.g.  `camview -v -c`

### Authentication:
Camview requires a ~/.config/camview.json file with Unifi Protect API credentials.
It must contain your Unifi Protect host IP or DNS name, and your API token.  Like this:
```json
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
```
