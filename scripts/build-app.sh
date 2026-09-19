#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
RESOURCE_DIR="$BIN_DIR/CodexLimitBar_CodexLimitBar.bundle"
if [[ -d "$RESOURCE_DIR/Contents/Resources" ]]; then
  RESOURCE_DIR="$RESOURCE_DIR/Contents/Resources"
fi

APP="$ROOT/dist/CodexLimitBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BIN_DIR/CodexLimitBar" "$APP/Contents/MacOS/CodexLimitBar"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Sources/CodexLimitBar/Resources/limitbar-mark.svg" "$APP/Contents/Resources/"
cp -R "$RESOURCE_DIR/"*.lproj "$APP/Contents/Resources/"
SPARKLE="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$ROOT/.build/artifacts/sparkle/Sparkle/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"

ICON_SOURCE="$ROOT/Sources/CodexLimitBar/Resources/AppIcon.svg"
ICONSET="$ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for spec in \
  "16:icon_16x16.png" \
  "32:icon_16x16@2x.png" \
  "32:icon_32x32.png" \
  "64:icon_32x32@2x.png" \
  "128:icon_128x128.png" \
  "256:icon_128x128@2x.png" \
  "256:icon_256x256.png" \
  "512:icon_256x256@2x.png" \
  "512:icon_512x512.png" \
  "1024:icon_512x512@2x.png"
do
  size="${spec%%:*}"
  name="${spec#*:}"
  sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Sign nested code from the inside out; preserve framework symlinks.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for nested in "$FRAMEWORK/Autoupdate" "$FRAMEWORK/Updater.app" "$FRAMEWORK/XPCServices/"*.xpc; do
  codesign --force --sign - "$nested"
done
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
print "Built $APP"
