# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Moblin is a free iOS/iPadOS IRL streaming app (Swift/SwiftUI) targeting Twitch, YouTube, Kick, Facebook
and OBS Studio. It streams over RTMP(S), SRT(LA), RIST and WHIP/WebRTC, with SRTLA/RIST bonding over
multiple network interfaces. The repo also contains an Apple Watch companion, a Live Activity extension,
a home screen widget, a screen recording broadcast extension, and a SolidJS web remote control frontend.

## Setup

1. `cp User.template.xcconfig Config/User.xcconfig`, then set `DEVELOPMENT_TEAM` and
   `BASE_PRODUCT_BUNDLE_IDENTIFIER`. `CAPABILITIES` selects which entitlements file each target uses
   (`Moblin/Moblin.$(CAPABILITIES).entitlements`) — use `free` unless you know you need `all`.
2. `open Moblin.xcodeproj` and wait for SPM packages to resolve. `Command + B` builds, `Command + R` runs.
3. Python tooling lives in a venv — `make style`, `make lint` and `make test` fail with "command not found"
   without it:
   ```sh
   python3.14 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt -U
   ```
4. Swift/JS tooling: `brew install swiftlint swiftformat codespell oxfmt oxlint`.

Several SPM dependencies are `eerimoq` forks pinned to a branch (MetalPetal, Srt, Rist, DataChannel,
SwiftCube, VRMKit, CrcSwift, NWWebSocket, AlertToast). Bumping one is a commit of its own — see the
"Bump metal petal" commits.

## Commands

```sh
make style           # swiftformat + oxfmt + isort + black (auto-fix)
make style-check     # same, lint-only
make lint            # swiftlint --strict + oxlint + pylint + xcstringslint
make lint-fix        # auto-fix Localizable.xcstrings issues
make spell-check     # codespell
make periphery       # dead code detection (needs full index; slow)

make web-remote-control-frontend-prepare   # npm install
make web-remote-control-frontend-build     # tsc --noEmit + vite build → Moblin/RemoteControl/Web/

make machine-translate                     # fill missing translations in Localizable.xcstrings
```

CI (`.github/workflows/all.yml`) runs `style-check`, `lint`, `spell-check`, the web frontend build followed
by `git diff --exit-code`, and an `xcodebuild build` of the `Moblin` scheme. Two consequences: **the built
web assets in `Moblin/RemoteControl/Web/` are committed and must be regenerated whenever
`WebRemoteControlFrontend/` changes**, and **CI never runs the unit tests** — run them yourself.

### Unit tests

Swift Testing (not XCTest): suites are `struct *Suite` in `MoblinTests/` using `@Test` and `#expect`.

```sh
# Command + U in Xcode, or:
xcodebuild test -scheme Moblin -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:MoblinTests/UtilsSuite/fullDuration
```

A handful of formatting tests in `UtilsSuite` and `TextEffectSuite` are gated on
`@Test(.enabled(if: Locale.current.identifier == "en_SE"))` and silently skip under any other locale.

### Integration tests

`test/` holds a Python harness that drives a real device against `mediamtx`/`ffmpeg`. It needs
`config.toml` (copy `config.example.toml`) and settings imported into the device — see `test/README.md`.

```sh
make test
make test TEST_ARGS="--device macpro Talkback"
```

## Architecture

### Settings vs Model — the central split

Two parallel object graphs, and picking the wrong one is the most common mistake:

- **`Moblin/Various/Settings/`** — persisted user configuration. `Settings` owns a `Database` serialized to
  JSON on disk; `Settings.store()` writes it. Everything here is `Codable`.
- **`Moblin/Various/Model/`** — runtime state (is live, current bitrate, connected devices, active effects).
  Not persisted.

Settings classes are `Codable, Identifiable, ObservableObject` with `@Published` properties and
**hand-written `encode(to:)`/`init(from:)`**. Decoding goes through the helper in
`Common/Various/CommonUtils.swift`:

```swift
name = container.decode(.name, String.self, "")   // never throws; falls back to the default
```

This is what makes old settings files forward-compatible, so a new property needs a `CodingKey`, an
`encode` line and a `decode` line with a sensible default — omitting them silently drops the value on
reload. Enum raw values (`case text = "Text"`) are the persisted representation and must not be renamed;
`toString()` supplies the localized display string instead.

Structural changes that defaults cannot express go in `Settings.migrateFromOlderVersions()`
(`Settings.swift`), which uses per-object `migrated` boolean flags and calls `store()` as it goes.

Secrets are kept out of the JSON: `store()` calls `extractSensitiveData` to null out tokens before
writing and `insertSensitiveData` to restore them, with the real values living in the Keychain
(`Keychain.swift`, `addSensitiveData` on load).

### Model — one class, ~100 extensions

`Model` (`Moblin/Various/Model/Model.swift`) is a single `final class Model: NSObject, ObservableObject`
split across ~60 `ModelXxx.swift` files, each an `extension Model` for one feature area (`ModelChat`,
`ModelTwitch`, `ModelRecording`, …). New feature code belongs in its own `extension Model` file, not in
`Model.swift`.

This codebase uses **`ObservableObject`/`@Published`, not the `@Observable` macro** — there are zero uses
of `@Observable`. Because a single `@Published` change on a class this large would invalidate every
observing view, `Model.swift` declares many small `ObservableObject` "provider" classes (`Bitrate`,
`Bonding`, `Battery`, `StatusTopLeft`, `Toast`, `StreamOverlay`, `SceneSelector`, …). Views observe the
narrow provider they need. Put frequently-changing state on a provider, not on `Model` directly.

### Media pipeline

`Moblin/Media/HaishinKit/` is a heavily modified fork of HaishinKit, embedded rather than depended on —
treat it as project source. `Moblin/Various/Media.swift` is the facade the `Model` talks to; it wraps a
`Processor` and reports back through the fat `MediaDelegate` protocol (`mediaOnSrtConnected`,
`mediaOnFps`, `mediaOnRecorderDataSegment`, …), which `Model` implements.

Capture and composition happen in `VideoUnit`/`AudioUnit`; encoding in `Codec/`; transports live beside
the fork in `Srtla/`, `RistServer/`, `RtmpServer/`, `RtspClient/`, `Webrtc/`, `WiFiAware/`. Adaptive
bitrate algorithms are pluggable under `AdaptiveBitrate/` (Belabox, Fight, RIST experiment).

**Moblink** (`Moblin/Moblink/`) is Moblin's own protocol for borrowing other phones' network connections
as extra bonding links — a streamer/relay pair over the local network.

### Video effects — two rendering backends

`Moblin/VideoEffects/` holds everything drawn on the stream. Each subclasses `VideoEffect`
(`Moblin/Media/HaishinKit/Media/Video/VideoEffect.swift`), which exposes **parallel CoreImage and
MetalPetal paths**:

```swift
func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage           // CoreImage
func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage // MetalPetal
```

`VideoUnit` picks the backend at runtime (`isMetalPetalGraphics`), and an effect overriding
`isMetalPetal() -> true` forces the whole pipeline onto MetalPetal
(`isMetalPetalGraphicsForcedByEffects`). A new effect should therefore implement both paths; implementing
only one makes it silently a no-op under the other backend. `VideoEffectInfo` carries the frame's
timestamp plus cached Vision results — request them via `needsFaceDetections`/`needsTextDetections`
rather than running Vision inside `execute`.

Effects reach the pipeline through `Media.registerEffect`/`unregisterEffect` for standalone effects, and
`Media.setPendingAfterAttachEffects` for the ordered per-scene list that `ModelScene` rebuilds on every
scene change.

### Adding a widget type

A widget is a `SettingsWidgetType` case whose raw value is persisted, so a new one has to be wired through
several files that a single-file search will not reveal:

- `SettingsScene.swift` — the enum case, its `toString()` localization, and the settings class
- `ModelScene.swift` — the `switch` that maps the widget to its `addScene*Effects` call
- `VideoEffects/` — the effect itself (both rendering backends)
- `View/Settings/Scenes/Widgets/Widget/` — `WidgetSettingsView` and `WidgetWizardSettingsView`
- `RemoteControl/RemoteControl.swift` — if the widget is controllable remotely

### Remote control and companions

`Moblin/RemoteControl/` implements a streamer/assistant pair over WebSocket, with `RemoteControlRelay`
for traversal and `RemoteControlWeb` serving the built SolidJS frontend from `Web/`.

The Watch app talks to the phone over `WatchConnectivity` using the string-keyed message envelope in
`Moblin Watch/Shared/WatchProtocol.swift` (`WatchMessageToWatch`/`WatchMessageFromWatch` plus
`pack`/`unpack`). Both sides of a new message must be added there.

## Conventions

- `swiftformat` at 110 columns, Swift 5.9 mode, `--disable docComments --ifdef no-indent`.
- `swiftlint --strict`. Many rules are off (see `.swiftlint.yml`) — notably `force_cast`, `force_try`,
  `identifier_name`, `cyclomatic_complexity` and `function_body_length`, so long `switch`-heavy functions
  and `try!` are idiomatic here.
- All user-facing strings go through `String(localized:)` and live in `Common/Localizable.xcstrings` —
  never `.strings` files. `utils/xcstringslint.py` (part of `make lint`) checks that format specifiers
  match across translations and that multi-specifier strings use positional `%1$@` forms.
- `Moblin/Integrations/Tesla/Protobuf/` is generated and excluded from formatting and periphery.
- `Moblin/RemoteControl/Web/` is build output — edit `WebRemoteControlFrontend/` instead.
- Code shared between the app, watch, and extensions goes in `Common/`.
- The `moblin://?<url-encoded JSON>` settings import format is defined by `MoblinSettingsUrl.swift`; its
  members are the JSON keys, and the README documents it for users.
