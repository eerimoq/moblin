# Moblin Remote Control Web (Svelte source)

This directory contains the Svelte 5 + Vite source for the Moblin remote control web pages.

## Pages

| Page | Description |
|------|-------------|
| `index.html` | Main remote control (live/recording/muted toggles, scene/mic/bitrate selection, SRT priorities, gimbal, filters, log) |
| `remote.html` | Scoreboard control (team scores, clock, match management for various sports) |
| `golf.html` | Golf scoreboard (players, holes, scores, leaderboard, scorecard) |
| `recordings.html` | Recording management (list, download, copy link, delete) |
| `scoreboard.html` | Scoreboard display overlay (fullscreen team scores with colors) |

## Development

```bash
# Install dependencies
npm install

# Build (outputs to Moblin/RemoteControl/Web/)
npm run build

# Development server (local preview only — WebSocket won't connect without the iOS app)
npm run dev
```

Or from the repo root:

```bash
make build-web-remote-control
```

## Architecture

- **`src/lib/websocket.js`** — `WebSocketConnection` base class; imports `websocketPort` from `/js/config.mjs` which the iOS server generates at runtime.
- **`src/lib/confirm.js`** — Shared confirm-dialog helpers (fallback for pages that don't use Svelte's `<dialog>`).
- **`src/*.svelte`** — One Svelte component per page; each is fully self-contained (CSS loaded via `<svelte:head>` at runtime).
- **`vite.config.js`** — Multi-page Vite build; outputs to `../Moblin/RemoteControl/Web/`; marks `/js/config.mjs` as an external (runtime) import.

## Build Output

Vite outputs:
- `Moblin/RemoteControl/Web/{index,remote,golf,recordings,scoreboard}.html`
- `Moblin/RemoteControl/Web/js/{index,remote,golf,recordings,scoreboard}.js` — per-page entry bundles
- `Moblin/RemoteControl/Web/js/*-chunk.js` — shared Svelte runtime chunks

The iOS HTTP server (`RemoteControlWeb.swift`) serves these via a dynamic `/js/` route handler that reads any `*.js` file from the app bundle.
