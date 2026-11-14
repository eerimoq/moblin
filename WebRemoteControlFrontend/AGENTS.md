# Web remote control frontend

The pages `RemoteControlWeb` serves from the device: SolidJS + TypeScript + Tailwind v4, built with Vite.

```sh
just web-remote-control-frontend-prepare   # npm install
just web-remote-control-frontend-build     # tsc --noEmit + vite build → ../Moblin/RemoteControl/Web/
```

- The build output in `Moblin/RemoteControl/Web/` is committed and is what the app serves. Rebuild after
  every change here and commit both; CI fails on any difference. Never edit the output by hand.
- Multi-page, no router. Adding a page takes the HTML file, its `src/*.tsx` entry and its line in
  `rollupOptions.input` in `vite.config.js`.
- `/js/config.mjs` is not built: `RemoteControlWeb.swift` generates it at request time with the WebSocket
  port, so it is marked `external` and declared in `src/config.d.ts`.
- `src/utils.ts` holds the WebSocket connection and the protocol types. Requests mirror the cases of
  `RemoteControlRequest` in `Moblin/RemoteControl/RemoteControl.swift` (`{ setLive: { on } }`), so a
  change to one side needs the same change on the other.
- Formatted with `oxfmt` and linted with `oxlint` (`just style`, `just lint`).
