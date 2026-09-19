#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/scripts/Info.plist")"
RELEASE_DIR="$ROOT/release"
STAGING_DIR="$ROOT/.build/dmg-root"
DMG="$RELEASE_DIR/Codex-Limit-Bar-$VERSION.dmg"

"$ROOT/scripts/build-app.sh"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$RELEASE_DIR"
cp -R "$ROOT/dist/CodexLimitBar.app" "$STAGING_DIR/Codex Limit Bar.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG" "$DMG.sha256"
hdiutil create \
  -volname "Codex Limit Bar" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG"

(cd "$RELEASE_DIR" && shasum -a 256 "${DMG:t}" > "${DMG:t}.sha256")
"$ROOT/scripts/build-appcast.sh"
print "Built $DMG"
