# GitHub releases and signed updates

Run `./scripts/build-dmg.sh` to create the versioned DMG, SHA-256 checksum, and signed `appcast.xml` in this directory. The command builds the app, embeds Sparkle, and signs the app bundle ad-hoc as before. Sparkle's update signatures are independent of Apple Developer ID signing and notarization.

The DMG contains `Codex Limit Bar.app` and an `Applications` shortcut. Move the app into Applications before launching it. The first installed launch offers to enable launch at login; the gear button also provides this setting and update controls.

## Signing key

The existing Ed25519 private key is stored only in the maintainer's login Keychain, using Sparkle's `generate_keys` tool with account `codex-limitbar`. Its public key is in `scripts/Info.plist`. `build-appcast.sh` verifies the key matches before generating a feed.

Keep a secure backup of this key using Sparkle's documented export/import process. Do not commit the private key, put it in a release, or replace it with a newly generated key for an ordinary update. A fresh checkout can build the app, but publishing updates requires the existing private key. Restore that key on a replacement release machine.

## Publish a version

1. Increase both `CFBundleShortVersionString` and the monotonically increasing `CFBundleVersion` in `scripts/Info.plist`. Update README versions and HTTP user-agent versions.
2. Write `release/VERSION.md` with release notes. These are also embedded in the signed feed.
3. Run `swift test` and `./scripts/build-dmg.sh`.
4. Verify the DMG and signatures. Test installation using a copy with a lower build number and a local signed feed before publishing updater changes.
5. Commit and push the source, then create and push the matching `vVERSION` tag.
6. Create a GitHub release with all three assets: `Codex-Limit-Bar-VERSION.dmg`, its `.sha256`, and `appcast.xml`. Upload all assets to a draft, then publish it as the latest stable release.

The app uses `https://github.com/svllvsxprod/codex_limitbar/releases/latest/download/appcast.xml`. Each feed points to the immutable versioned DMG URL. Do not publish a latest release without its signed feed, and do not modify a signed feed after generation. Keep older releases available. Users of 0.3.0 and earlier need to install 0.4.0 manually once to obtain the updater.

## Update behavior

Sparkle checks every six hours by default. Users can disable automatic checks or check manually from the gear menu. New versions are offered through Sparkle's UI and an in-menu reminder. Downloads and installation require confirmation; silent automatic installation is disabled. The update archive is verified before extraction, and the feed is signed too. System profiling is disabled.

This updater belongs to the GitHub distribution. A future Mac App Store target must omit Sparkle and use App Store updates.
