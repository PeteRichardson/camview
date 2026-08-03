# Streamdeck Extras

### TLDR
This folder contains the pieces used to build tiny macOS apps that just call camview with a single liveview name.  They're suitable for launching from an Elgato Streamdeck button.

Build them all with:

```sh
./Scripts/build-launchers.sh
```

They run `~/bin/camview`, so install that first:

```sh
swift build -c release && cp .build/release/camview ~/bin/
```


### Details
Camview was written to help switch liveviews on a Unifi Protect Viewport, and I wanted to switch views by pushing buttons on an Elgato StreamDeck.

The streamdeck prefers launching full gui apps, and there is not (to my knowledge) an easy way to parameterize the streamdeck buttons.  In other words, ideally I would launch the same app on each button, but pass in some distinct Liveview name, but that's not possible.  So, we need a different app for each button.

You can use Automator.app to wrap a command line in a macOS app.   It's easy and works well, but it's a little tedious when building many apps and the apps were pretty big for what they did.  (3.3Mb including 3Mb of icons :-)) so I wrote a tiny mac app in swift that does nothing but launch camview with a particular liveview name.  To make it as small, simple and quick as possible, it doesn't have access to the users regular $PATH, so it's hardcoded to look for camview in a bin folder in your home directory (i.e. `~/bin/camview`).   It's easy enough to change in `Sources/StreamdeckLauncher/main.swift` if that doesn't work for you.

### How the apps get built

There is **one** launcher binary, not one per liveview.  `Sources/StreamdeckLauncher/main.swift` reads its own executable name from `argv[0]` and passes that to `camview show`:

```swift
let target = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingPathExtension()
    .lastPathComponent
```

`camview show` matches liveview names case-insensitively, so a copy named `driveway180` selects the `Driveway180` liveview with no lookup table to keep in sync.  `Scripts/build-launchers.sh` builds that binary once and copies it to each name in its `VIEWS` list.

**The `VIEWS` array in that script is the only place the liveview list lives.**  Adding a button means adding one word to it; deleting a word retires that button, and the next run prunes the orphaned `.app`.

Every entry must name a liveview that actually exists, or its button silently does nothing.  Cross-check with:

```sh
camview list liveviews -f csv | tail -n +2 | cut -d, -f1
```

#### Other notes:
* Each binary is nested in a `<LiveviewName>.app/Contents/MacOS` hierarchy to stop the Finder and the Stream Deck from launching a terminal window.  `Info.plist.template` is the template for each bundle's `Info.plist`, with `REPLACEME` substituted for the liveview name.  The `LSUIElement` key in it is what keeps the launchers out of the Dock and Cmd-Tab.
* The generated `apps/` folder is gitignored.  It's build output; the script recreates it.
* Each bundle is ad-hoc signed after its `Info.plist` is written.  Without that step the bundle inherits the linker's signature, which describes a bare executable and claims a resource seal the bundle can't satisfy, so `codesign -v` fails.  Ad-hoc signing still won't satisfy Gatekeeper — fine for locally built, unquarantined apps, but they aren't distributable as-is.
* The prune step only removes `*.app`, so anything else you keep in `apps/` survives — including a hand-made Automator app, if you'd rather use one of those for a particular button.
* One improvement would be to have the script ask camview for the current list of Liveviews and generate an app for each, instead of keeping the list in `VIEWS`.  Nothing but the cross-check above stops the two drifting apart.
* To get nice images for your streamdeck buttons, take a snapshot from your camera, crop it to a square, reduce it to 72x72 and black out the bottom 20 rows of pixels so the button title shows up nicely.
* If you do use Automator instead of these little launcher apps, it's pretty easy to edit the `Contents/document.wflow` file to change the command line.
