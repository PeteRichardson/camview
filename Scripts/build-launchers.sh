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
# Cross-check against reality with:
#     camview list liveviews -f csv | tail -n +2 | cut -d, -f1
#
# As of 2026-08-02 three entries below have no matching liveview in Protect and produce
# buttons that do nothing: all, familyroom, summary. They are kept because they were in
# the original build.nu list — delete them once you've confirmed they're unwanted.
VIEWS=(
  all           # no matching liveview as of 2026-08-02
  backyard180
  deck
  diningroom
  doorbell
  driveway180
  driveway2
  familyroom    # no matching liveview as of 2026-08-02
  firepit
  frontdoor
  garbage
  katsalley
  sideyard
  summary       # no matching liveview as of 2026-08-02
  default
)

APPS_DIR="streamdeck extras/apps"
TEMPLATE="streamdeck extras/Info.plist.template"

echo "Building StreamdeckLauncher..."
swift build -c release --product StreamdeckLauncher
BIN="$(swift build -c release --product StreamdeckLauncher --show-bin-path)/StreamdeckLauncher"

mkdir -p "$APPS_DIR"

for view in "${VIEWS[@]}"; do
    app="$APPS_DIR/$view.app"
    exe="$app/Contents/MacOS/$view"

    mkdir -p "$app/Contents/MacOS"
    cp "$BIN" "$exe"
    strip -x "$exe"
    sed "s/REPLACEME/$view/g" "$TEMPLATE" > "$app/Contents/Info.plist"

    printf "   ✅ %-14s %7s bytes\n" "$view" "$(stat -f%z "$exe")"
done

echo
echo "Built ${#VIEWS[@]} apps in $APPS_DIR"
echo "Note: these run ~/bin/camview — install it with:"
echo "   swift build -c release && cp .build/release/camview ~/bin/"
