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

1. Standard Codex auth at `~/.codex/auth.json`.
2. Local OpenCode OpenAI OAuth at `~/.local/share/opencode/auth.json`.

The OpenCode fallback is unsupported by OpenAI and may break when OpenCode changes its local auth format. It is used because this machine currently has an authenticated OpenCode session but no installed Codex CLI. The app only reads these files, keeps tokens in memory, and sends them only to `chatgpt.com`; it never modifies, stores, or logs them.

If a token expires, sign in again through the application that owns it. The app deliberately does not refresh or take ownership of another application's OAuth credentials.

## Failure behavior

- Missing local auth: source unavailable.
- HTTP 401: authentication failure.
- HTTP 403: unsupported account or authorization failure.
- HTTP 429: rate limit.
- Other HTTP/transport errors: network failure.
- Unknown or empty usage payload: malformed response.

The last successful snapshot remains visible as stale data after a failed refresh.

The app refreshes immediately when its menu panel opens and then every 15 seconds only while the panel remains visible. Closing the panel cancels periodic polling, avoiding continuous background requests.

Before reading local auth or contacting OpenAI, each refresh concurrently probes YouTube, Speedtest, and WhatsApp with credential-free `HEAD` requests. If all three fail, the app reports that the VPN is unavailable and does not contact OpenAI. This is an explicit product heuristic, not cryptographic proof that a VPN tunnel is active.
