# Moblin Web Connection Bonding With Moblink Relay Support

## Summary

- Create separate branches:
  - iOS Moblin: `/home/michael/Development/Swift/moblin`, branch `web-connection-bonding`.
  - Android Moblink: clone `https://github.com/eerimoq/Moblink` to
    `/home/michael/Development/Android/Moblink`, branch `web-proxy-relay`.
- Fix Moblin web traffic so bad Wi-Fi does not break overlays or app web features when cellular is healthy.
- Keep the feature off by default and enable it only from the Moblin Debug settings menu.
- Add best-effort direct routing over iPhone cellular, Wi-Fi, Ethernet,
  and other interfaces where iOS exposes them.
- Add Moblink web relay support for new iOS Moblin and Android Moblink peers,
  gated by explicit capability negotiation.
- Preserve existing SRTLA/Moblink stream bonding and compatibility with older Moblink versions.

## Design

- Add a shared iOS `WebNetworkRouteSelector`:
  - Tracks available direct interfaces with `NWPathMonitor`.
  - Tracks compatible Moblink relay routes.
  - Uses Apple Multipath TCP first when the app has the entitlement and iOS reports cellular plus Wi-Fi.
  - Chooses routes using direct route preference plus failures, cooldown, and active connection count.
  - Uses all healthy routes across concurrent web connections.
  - If a route fails, retries on the next safe route.
- Add a localhost-only iOS web proxy:
  - Starts only when the Debug setting is enabled.
  - Supports HTTP requests and HTTPS `CONNECT`.
  - Does not inspect TLS, cookies, OAuth tokens, passwords, or response bodies.
  - Routes browser overlays, in-app browser, auth WebViews, app HTTP, and app WebSockets where supported.
  - Uses WebKit proxy configuration behind OS availability checks.
  - On older iOS without WebKit proxy support, keeps WebKit on system routing
    but still improves Moblin-owned HTTP/WebSocket traffic.
- Extend Moblink protocol:
  - Add capability negotiation for web relay support.
  - Add TCP tunnel open, data, close, and error messages.
  - Send web relay messages only after the peer advertises support.
  - Mark web relay unsupported per peer if negotiation fails.
  - Keep old peers connected for existing SRTLA bonding.
- Add relay implementations:
  - iOS Moblin built-in Moblink can act as a web relay.
  - Android Moblink gets matching relay support after cloning and inspecting its project conventions.
  - Multiple compatible relays can carry different web connections at the same time.

## Compatibility

- Old iOS or Android Moblink versions:
  - No web relay messages are sent.
  - Existing SRTLA bonding remains unchanged.
  - Direct iPhone routes still handle web traffic.
- New iOS and Android Moblink versions:
  - Advertise web relay capability.
  - Join the web routing pool when healthy.
  - Drop out safely on disconnect, timeout, or protocol error.
- Direct iPhone Wi-Fi plus cellular:
  - Uses Apple Multipath TCP for packet-level direct bonding where entitled and supported.
  - Falls back to connection-level bonding and failover.
  - Uses Apple Multipath TCP only where available, entitled, and supported by the destination server.
  - Does not claim packet-level bonding for arbitrary HTTPS servers.

## Test Plan

- iOS unit tests:
  - Route ordering: entitled direct multipath, cellular, compatible relays, Ethernet, Wi-Fi, other.
  - Route health scoring, failure cooldown, and recovery.
  - HTTP proxy parsing for absolute-form HTTP and HTTPS `CONNECT`.
  - Proxy rejects malformed or unsafe requests.
  - Moblink capability negotiation with supported and unsupported peers.
  - Old Moblink peer keeps SRTLA support and never receives web relay messages.
- iOS integration/manual tests:
  - Bad Wi-Fi hotspot plus good cellular keeps overlays working.
  - App HTTP/WebSocket traffic uses direct routing on older iOS.
  - WebKit proxying works on supported iOS.
  - Auth WebViews still complete login where proxying is supported.
  - Multiple Moblink relays are used across concurrent web connections.
  - Relay drop and restore does not break direct routing.
- Android tests:
  - Run discovered Gradle checks.
  - Protocol serialization compatibility with iOS Moblin.
  - TCP relay open, forwarding, close, timeout, and cleanup.
  - Compatibility with old iOS Moblin peers.
- Cross-device tests:
  - iOS Moblin plus old Android Moblink.
  - iOS Moblin plus new Android Moblink.
  - iOS Moblin plus another new iOS Moblin relay.
  - Mixed multiple relays with one bad relay.

## Assumptions

- "All web traffic within Moblin" means Moblin-owned HTTP, WebSocket,
  browser overlays, in-app browser, and auth WebViews.
- v1 bonding is connection-level bonding for generic web traffic: all healthy
  paths can be used at once across different web connections.
- A single HTTPS/TCP connection uses Apple Multipath TCP only where iOS,
  entitlements, and the destination support it.
- True single-flow bonding across multiple Moblink devices would require an
  aggregation server or relay-to-relay transport and is out of this proposal.
- Code must match Moblin Swift style, Android Moblink style after inspection, and `~/AGENTS.md`.
