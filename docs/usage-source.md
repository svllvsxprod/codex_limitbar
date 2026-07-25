# Codex usage source

## Selected integration

The app requests:

```text
GET https://chatgpt.com/backend-api/wham/usage
```

This is the route used by the official open-source Codex backend client. The response reports `used_percent`, the window duration, and the Unix reset timestamp. The app computes remaining percentage as `100 - used_percent` and does not infer quota from token counts or billing data.

Authoritative references:

- Codex app-server protocol: https://github.com/openai/codex/tree/main/codex-rs/app-server
- Official `account/rateLimits/read` response types: https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/v2/account.rs
- Official backend route implementation: https://github.com/openai/codex/blob/main/codex-rs/backend-client/src/client/rate_limit_resets.rs

## Authentication order

1. App-owned ChatGPT OAuth stored in macOS Keychain.
2. Standard Codex auth at `~/.codex/auth.json`.
3. Local OpenCode OpenAI OAuth at `~/.local/share/opencode/auth.json`.

The app-owned session is created with the ChatGPT device authorization flow. The one-time code is copied to the pasteboard and the OpenAI device page opens in the default browser. Access and refresh tokens are stored as a non-synchronizing generic password in the user's macOS login Keychain with after-first-unlock accessibility.

The app refreshes only its own Keychain credential. The OpenCode fallback is unsupported by OpenAI and may break when OpenCode changes its local auth format. Codex Limit Bar only reads external auth files and never modifies or refreshes another application's credentials.

## Failure behavior

- Missing local auth: source unavailable.
- HTTP 401: authentication failure.
- HTTP 403: unsupported account or authorization failure.
- HTTP 429: rate limit.
- Other HTTP/transport errors: network failure.
- Unknown or empty usage payload: malformed response.

The last successful snapshot remains visible as stale data after a failed refresh.

After macOS wakes from sleep, the app schedules refreshes after 3 and 15 seconds so network and VPN routes have time to recover. A `401` response is retried once: app-owned credentials are refreshed through OpenAI OAuth, while an external fallback is only re-read from its owning client's file.

The app refreshes immediately when its menu panel opens and then every 15 seconds only while the panel remains visible. Closing the panel cancels periodic polling, avoiding continuous background requests.

Before reading local auth or contacting OpenAI, each refresh concurrently probes YouTube, Speedtest, and WhatsApp with credential-free `HEAD` requests. If all three fail, the app reports that the VPN is unavailable and does not contact OpenAI. This is an explicit product heuristic, not cryptographic proof that a VPN tunnel is active.
