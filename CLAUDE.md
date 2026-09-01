# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Moblin is a free iOS/iPadOS IRL streaming app (Swift/SwiftUI) targeting Twitch, YouTube, Kick, Facebook
and OBS Studio. It streams over RTMP(S), SRT(LA), RIST and WHIP/WebRTC, with SRTLA/RIST bonding over
multiple network interfaces. The repo also contains an Apple Watch companion, a Live Activity extension,
a home screen widget, a screen recording broadcast extension, and a SolidJS web remote control frontend.

## Commands

```sh
make style           # swiftformat + oxfmt + isort + black (auto-fix)
make style-check     # same, lint-only
make lint            # swiftlint --strict + oxlint + pylint + ruff check + mypy + xcstringslint
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

**Always run the unit tests for Mac Catalyst, never for a simulator or a device, when a test run is needed:**

```sh
xcodebuild test -scheme Moblin -destination 'platform=macOS,variant=Mac Catalyst'
```

### System tests

`tests/` holds a Python harness that drives a real device against `mediamtx`/`ffmpeg`. Ask user to 
start the app before running the test commands.

```sh
make test
make test TEST_ARGS="--device macpro Talkback"
make test-stability                        # long-running soak test, 12 hours by default
```

The harness runs with `tests/` as the working directory, so its imports are `from utils.moblin import
Moblin`, while `make lint` type checks `tests/` and `utils/` from the repo root. That only works while
every module name is unique across both trees — `tests/suites/` and `tests/utils/` are packages
(`__init__.py`) so that `tests/suites/stability.py` does not collide with the `tests/stability.py` entry
point. Adding a `utils/x.py` that shadows a `tests/x.py` (or dropping an `__init__.py`) makes mypy abort
with "Duplicate module named ..." instead of checking anything.

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

- **Do not write comments or docstrings.** The one exception is a system test case class in `tests/suites/`,
  which gets a one-line docstring describing what the test does (`"""Play talkback sound over RTMP server
  through the speaker for 10 seconds."""`).
- **Magic numbers are fine, and often preferred, when used in a single place.** Do not hoist a literal
  into a named constant just because it is a literal — only name it when the same value is used in more
  than one place.
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
