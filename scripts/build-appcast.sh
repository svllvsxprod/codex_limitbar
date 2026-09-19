#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/scripts/Info.plist")"
TOOLS="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
ACCOUNT="codex-limitbar"
EXPECTED_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$ROOT/scripts/Info.plist")"
ACTUAL_KEY="$("$TOOLS/generate_keys" --account "$ACCOUNT" -p)"
if [[ "$EXPECTED_KEY" != "$ACTUAL_KEY" ]]; then
  print -u2 "The Sparkle signing key does not match the public key in Info.plist."
  exit 1
fi

STAGING="$(mktemp -d "$ROOT/.build/appcast.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
NAME="Codex-Limit-Bar-$VERSION"
cp "$ROOT/release/$NAME.dmg" "$STAGING/"
if [[ -f "$ROOT/release/$VERSION.md" ]]; then
  cp "$ROOT/release/$VERSION.md" "$STAGING/$NAME.md"
fi

"$TOOLS/generate_appcast" \
  --account "$ACCOUNT" \
  --download-url-prefix "https://github.com/svllvsxprod/codex_limitbar/releases/download/v$VERSION/" \
  --link "https://github.com/svllvsxprod/codex_limitbar/releases/tag/v$VERSION" \
  --embed-release-notes \
  --maximum-deltas 0 \
  "$STAGING"
"$TOOLS/sign_update" --account "$ACCOUNT" --verify "$STAGING/appcast.xml"
cp "$STAGING/appcast.xml" "$ROOT/release/appcast.xml"
print "Built signed $ROOT/release/appcast.xml"
