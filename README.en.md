<p align="center">
  <a href="README.md">Русский</a> · <b>English</b>
</p>

<p align="center">
  <img src="Sources/CodexLimitBar/Resources/AppIcon.svg" alt="Codex Limit Bar" width="150" />
</p>

<h1 align="center">Codex Limit Bar</h1>

<p align="center">
  A native OpenAI Codex usage-limit indicator for the macOS menu bar.
</p>

<p align="center">
  <a href="https://github.com/svllvsxprod/codex_limitbar/releases/latest">Download the latest release</a>
</p>

<table align="center">
  <tr>
    <td align="center" width="760">
      <h3>Support development</h3>
      <p>Your support helps improve the app, validate new Codex releases, and prepare signed builds.</p>
      <table align="center">
        <tr>
          <td align="center" width="350"><a href="https://t.me/tribute/app?startapp=dK9j"><img src="docs/readme/support-tribute.svg" width="340" alt="Support development through Tribute" /></a></td>
          <td align="center" width="350"><a href="https://nowpayments.io/donation/svllvsx"><img src="docs/readme/support-nowpayments.svg" width="340" alt="Support development through NOWPayments" /></a></td>
        </tr>
        <tr>
          <td align="center" colspan="2"><a href="https://t.me/svllvsxprod"><img src="docs/readme/telegram.svg" width="340" alt="svllvsxprod Telegram channel" /></a></td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&amp;logo=swift&amp;logoColor=white">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&amp;logo=apple&amp;logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple_Silicon-ready-555555?style=for-the-badge&amp;logo=apple&amp;logoColor=white">
  <img alt="Release 0.3.0" src="https://img.shields.io/badge/release-0.3.0-18A66A?style=for-the-badge">
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#security">Security</a> ·
  <a href="#development">Development</a> ·
  <a href="#limitations">Limitations</a>
</p>

## About

Codex Limit Bar lives exclusively in the menu bar and shows the actual remaining Codex percentage, usage-window duration, and next reset time. It does not create a regular window or occupy space in the Dock.

Usage data is refreshed immediately after launch and then every three minutes in the background. The last successful result remains available as a stale snapshot when a temporary error occurs.

This project is an independent utility and is not affiliated with OpenAI.

## Interface

<p align="center">
  <img src="docs/readme/screenshots/codex-limit-bar.png" alt="Codex Limit Bar in the macOS menu bar" width="560" />
</p>

## Features

- Actual remaining usage for the primary weekly or short Codex window.
- Additional model limits when they are present in the account response.
- Exact local time of the next reset.
- Explicit loading, stale-data, expired-authentication, rate-limit, network, VPN-gate, and unknown-format states.
- Manual refresh with coalescing to prevent duplicate concurrent requests.
- Background usage refresh every three minutes, including while the panel is closed.
- Launch at login through the system `SMAppService` API.
- Independent ChatGPT device login with an app-owned session stored in macOS Keychain.
- Dynamic remaining percentage beneath the OpenAI blossom in the menu bar.
- Accumulated primary Codex-window usage spent during the current day.
- Automatic English or Russian UI localization based on the macOS language.
- Native SwiftUI and AppKit implementation with no third-party runtime dependencies.

## Installation

1. Download `Codex-Limit-Bar-0.3.0.dmg` from [GitHub Releases](https://github.com/svllvsxprod/codex_limitbar/releases/latest).
2. Open the DMG and drag `Codex Limit Bar.app` into `Applications`.
3. Launch the app. Because the current build is ad-hoc signed, macOS may require the first launch through the **Open** context-menu command.
4. Select **Independent sign-in** in the app panel, paste the copied code into the ChatGPT page that opens, and complete authorization.
5. If needed, allow launch at login under **System Settings → General → Login Items**.

Before independent sign-in, the app may temporarily use local Codex CLI or OpenCode authentication as a read-only fallback. After sign-in, Codex Limit Bar stores and refreshes its own session independently of a running OpenCode process.

## VPN Check

Before each OpenAI request, the app concurrently sends credential-free `HEAD` requests to YouTube, Speedtest, and WhatsApp.

- If at least one service responds, the OpenAI request is allowed.
- If all three services are unavailable, the app does not read the local token or contact OpenAI.
- Each probe has a five-second timeout.

This is a product-level connectivity heuristic, not a check for a specific VPN interface or route.

## Architecture

```text
MenuBarExtra window
  -> UsageStore
  -> PublicServiceConnectivityGate
  -> ChatGPTAuthManager / Keychain
  -> LocalChatGPTAuthLoader fallback
  -> LiveCodexUsageProvider
  -> chatgpt.com/backend-api/wham/usage
```

- The UI depends on `CodexUsageProviding`, not on the transport response.
- Parsing, OAuth retry, local authentication, wake refresh, VPN gate, and refresh state are tested independently.
- Refresh requests are coalesced and cannot create overlapping polling loops.
- The release pipeline builds the `.app`, `.icns`, DMG, and SHA-256 checksum.

## Security

- Tokens are never written to source code, fixtures, logs, or release artifacts.
- Authentication files are accepted only when their POSIX permissions deny group and other access.
- The app-owned Codex Limit Bar OAuth session is stored as a generic password in macOS Keychain.
- The token is kept only in memory and sent exclusively to the exact `chatgpt.com` HTTPS origin.
- VPN probes never receive the token, account ID, or other OpenAI credentials.
- The app uses ephemeral `URLSession` instances, disabled URL caching, and bounded timeouts.
- Codex and OpenCode authentication files are read-only; only the app-owned Keychain session can be updated.

Data-source details: [`docs/usage-source.md`](docs/usage-source.md).

## Development

Requirements:

- macOS 14 or newer.
- Xcode 26 / Swift 6.2 or newer.
- Apple Silicon for the current prebuilt DMG.

```bash
swift test
swift run CodexLimitBar
```

Build the app bundle:

```bash
./scripts/build-app.sh
open dist/CodexLimitBar.app
```

Build the DMG:

```bash
./scripts/build-dmg.sh
```

The artifact and its SHA-256 checksum are written to `release/`.

## Limitations

- `wham/usage` is used by the official open-source Codex client but is not documented as a stable public API.
- The local OpenCode OAuth fallback is unsupported and may change with the OpenCode authentication format.
- The app does not update or take ownership of another client's OAuth credentials; independent device login creates a separate app-owned session.
- The current public DMG is built for Apple Silicon.
- The build is ad-hoc signed and not notarized by Apple; public production distribution requires Developer ID signing and notarization.
- macOS may require manual approval of the login item.
- Daily usage is derived from observed `used_percent` changes; the API cannot reconstruct usage while the app was not running.
