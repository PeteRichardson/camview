# Streamdeck Extras

### TLDR
This folder contains code to build tiny macOS apps that just call camview with a single liveview name.  They're suitable for launching from an Elgato Streamdeck button.


### Details
Camview was written to help switch liveviews on a Unifi Protect Viewport, and I wanted to switch views by pushing buttons on an Elgato StreamDeck.

The streamdeck prefers launching full gui apps, and there is not (to my knowledge) an easy way to parameterize the streamdeck buttons.  In other words, ideally I would launch the same app on each button, but pass in some distinct Liveview name, but that's not possible.  So, we need to generate a different app for each button.

You can use Automator.app to wrap a command line in a macOS app.   It's easy and works well, but it's a little tedious when building many apps and the apps were pretty big for what they did.  (3.3Mb including 3Mb of icons :-)) so I wrote a tiny mac app in swift that does nothing but launch camview with a particular liveview name.  To make it as small, simple and quick as possible, it doesn't have access to the users regular $PATH, so its hardcoded to look for camview at in a bin folder in your home directory (i.e. ~/bin/camview)   It's easy enough to change in the source code if that doesn't work for you.

There's script (build.nu) in nushell (sorry) to help build multiple apps from a list of Liveviews.  It's fairly straightforward, although the nu interpolation syntax gets in the way a bit.   Feel free to rewrite it in some other language or build system.

#### Other notes:
* The build.nu script nests each binary in a <LiveviewName>.app/Contents/MacOS folder hierarchy to stop the finder and StreamDesk from launching a terminal window.
* One improvement would be to have build.nu use camview to dynamically get the current list of Liveviews and generate an app for each one, instead of having a hardcoded list.
* To get nice images for your streamdeck buttons, take a snapshot from your camera, crop it to a square, reduce it to 72x72 and black out the bottom 20 rows of pixels so the button title shows up nicely.
* If you do use Automator instead of these little launcher apps, it's pretty easy to edit the Contents/document.wflow file to change the command line.
