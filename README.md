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

You can switch to a Liveview by passing the Liveview name on the cmd line.
Names are case-INsensitive.
```
camview Driveway
```

If you don't give a Liveview name, it will try a view called "Default"

You can list Viewports with -p and Liveviews with -v
You'll get a summary view of names and ids.
You can get more data in csv format by specifying -c.


### Limitations:
• camview changes the Liveview on only the *first* Viewport that the Protect API returns.

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
