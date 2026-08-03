#!/usr/bin/env bash
#
# Build the Stream Deck launcher apps.
#
# One binary is compiled and then copied to N names. Each copy derives its liveview from
# its own executable name at runtime, so adding a liveview means adding one word to VIEWS
# below — there is no second list to keep in sync.
#
# Nesting the binary in <name>.app/Contents/MacOS stops Finder and the Stream Deck from
# opening a terminal window when the button is pressed.

set -euo pipefail
cd "$(dirname "$0")/.."

# The only place the liveview list lives. Names are lowercase; camview matches
# liveview names case-insensitively.
#
# Every entry must name a real liveview, or its button does nothing. Cross-check with:
#     camview list liveviews -f csv | tail -n +2 | cut -d, -f1
#
# A name removed from this list has its .app pruned on the next run, so deleting an entry
# is enough to retire a button.
VIEWS=(
  backyard180
  deck
  default
  diningroom
  doorbell
  driveway180
  driveway2
  firepit
  frontdoor
  garbage
  katsalley
  sideyard
)

APPS_DIR="streamdeck extras/apps"
TEMPLATE="streamdeck extras/Info.plist.template"

echo "Building StreamdeckLauncher..."
swift build -c release --product StreamdeckLauncher
BIN="$(swift build -c release --product StreamdeckLauncher --show-bin-path)/StreamdeckLauncher"

mkdir -p "$APPS_DIR"

# Remove bundles left by an earlier run whose name is no longer in VIEWS. Without this the
# script only ever creates and overwrites, so deleting a name from VIEWS leaves its .app
# behind and the Stream Deck button keeps working.
#
# Scoped to *.app rather than wiping $APPS_DIR, so anything else kept in here — a hand-made
# Automator app, say, which the Stream Deck README offers as an alternative — survives.
shopt -s nullglob
for app in "$APPS_DIR"/*.app; do
    name="$(basename "$app" .app)"
    stale=true
    for view in "${VIEWS[@]}"; do
        if [ "$view" = "$name" ]; then
            stale=false
            break
        fi
    done
    if [ "$stale" = true ]; then
        rm -rf "$app"
        echo "   🗑  removed stale $name.app"
    fi
done
shopt -u nullglob

for view in "${VIEWS[@]}"; do
    app="$APPS_DIR/$view.app"
    exe="$app/Contents/MacOS/$view"

    mkdir -p "$app/Contents/MacOS"
    cp "$BIN" "$exe"
    strip -x "$exe"
    sed "s/REPLACEME/$view/g" "$TEMPLATE" > "$app/Contents/Info.plist"

    # Re-sign as a bundle. The copied executable arrives carrying the linker's ad-hoc
    # signature, which describes a bare Mach-O and claims a resource seal the bundle has
    # no _CodeSignature to satisfy — so `codesign -v` on the .app fails even though the
    # same binary verifies fine on its own. --force replaces that signature rather than
    # refusing because one is already present.
    #
    # Must come last: signing seals Info.plist, so writing it afterwards would invalidate
    # the signature again.
    #
    # Output is captured rather than suppressed: on success codesign just says "replacing
    # existing signature" once per app, which buries the real output, but on failure its
    # message is the only explanation of what went wrong.
    if ! signing_output="$(codesign -s - --force "$app" 2>&1)"; then
        echo "   ❌ codesign failed for $view.app: $signing_output" >&2
        exit 1
    fi

    printf "   ✅ %-14s %7s bytes\n" "$view" "$(stat -f%z "$exe")"
done

echo
echo "Built ${#VIEWS[@]} apps in $APPS_DIR"
echo "Note: these run ~/bin/camview — install it with:"
echo "   swift build -c release && cp .build/release/camview ~/bin/"
