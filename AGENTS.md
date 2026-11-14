# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## What this is

Moblin is a free iOS/iPadOS IRL streaming app (Swift/SwiftUI) targeting Twitch, YouTube, Kick, Facebook
and OBS Studio. It streams over RTMP(S), SRT(LA), RIST and WHIP/WebRTC, with SRTLA/RIST bonding over
multiple network interfaces. The repo also contains an Apple Watch companion, a Live Activity extension,
a home screen widget, a screen recording broadcast extension, and a SolidJS web remote control frontend.

## Where the details are

Read the file for the part you are working on before changing it:

- `tests/AGENTS.md` — the system tests: launching the app, module names and how tests are written.
- `WebRemoteControlFrontend/AGENTS.md` — the web remote control frontend, its build and its protocol.

## Commands

```sh
just style           # swiftformat + oxfmt + isort + ruff format (auto-fix)
just style-check     # same, lint-only
just lint            # swiftlint --strict + oxlint + pylint + ruff check + mypy + xcstringslint
just lint-fix        # auto-fix Localizable.xcstrings issues
just spell-check     # codespell
just periphery       # dead code detection (needs full index; slow)

just machine-translate                     # fill missing translations in Localizable.xcstrings
```

CI (`.github/workflows/all.yml`) runs `style-check`, `lint`, `spell-check`, and the web frontend build followed
by `git diff --exit-code`. Two consequences: **the built web assets in `Moblin/RemoteControl/Web/` are
committed and must be regenerated whenever `WebRemoteControlFrontend/` changes**, and **CI never compiles
the app or runs the unit tests** — build and run them yourself.

### Building

`xcodebuild` fails without the gitignored `Config/User.xcconfig`. If it is missing, create it with
`cp User.template.xcconfig Config/User.xcconfig`, and never delete it afterwards.

Build and run only for Mac Catalyst or a real device. **Never use the iOS simulator**, for any purpose —
not for builds, debugging or reproducing UI bugs. Behavior that needs real hardware (rotation, camera,
safe areas) is reproduced on a USB-connected device.

### Unit tests

Swift Testing (not XCTest): suites are `struct *Suite` in `MoblinTests/` using `@Test` and `#expect`.

**Always run the unit tests for Mac Catalyst, never for a simulator or a device, when a test run is needed:**

```sh
xcodebuild test -scheme Moblin -destination 'platform=macOS,variant=Mac Catalyst'
```

`Moblin.xctestplan` gives every test a 60 second execution time allowance. A test that exceeds it fails with
"Time limit was exceeded", the test runner is killed and relaunched, and the run continues, so a hung test
can no longer stall the whole run.

Broad coverage (validation rules, every widget type, edge cases) belongs in unit tests. System tests only
cover a few important end-to-end cases; before adding a system test step, check whether a unit test can
cover it instead.

Each test calls the function under test directly in its body
(`#expect(isValidRemoteControlWidgetUpdate(widget: ..., new: ...))`). Fixtures and helpers may build data
(databases, widgets, round-tripped copies) but never wrap the tested call. Test data goes in
`@Test(arguments: [...])`, never in a `for` loop in the test body: one parameterized test per expectation,
with cases that conform to `CustomTestStringConvertible`. Give a case type at most one defaulted closure and
put starting state in the fixture's default objects — with two defaulted closures, an unlabeled trailing
closure binds to the first and the case silently tests nothing.

### System tests

`tests/` holds a Python harness that drives a real device (`just test`). Read `tests/AGENTS.md` before
running or changing them.

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

### Model — one class, many extensions

`Model` (`Moblin/Various/Model/Model.swift`) is a single `final class Model: NSObject, ObservableObject`
split across ~75 `ModelXxx.swift` files, each an `extension Model` for one feature area (`ModelChat`,
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

Scene and widget configuration over remote control must behave exactly like the Moblin UI: what it
accepts, rejects, resets and creates as defaults. The UI is always right, even where it looks slightly
wrong, so a remote control path that inherits a UI quirk is correct and is not a bug. It is a bug when a
remote update diverges from the UI or does more than the UI would for the same change (for example,
attaching the camera twice). The one exception: a wizard requirement that the widget's settings can fill in
later on the device (such as the file of an image, VTuber or PNGTuber widget) is not enforced on remote
create.

- Remote control handlers (`ModelRemoteControlScenes.swift`, `ModelRemoteControlSettingsUpdate.swift`, …)
  mutate the database and run the same reload/update calls as the UI, but never call `storeSettings()`.
- When moving a view's logic into a `Model` function so remote control can share it, keep the view's
  private method (`setEffectSettings()`, `updateEffect()`, …) and make its body call the model function,
  rather than inlining `model.xxx(widget: widget)` at every call site.

The Watch app talks to the phone over `WatchConnectivity` using the string-keyed message envelope in
`Moblin Watch/Shared/WatchProtocol.swift` (`WatchMessageToWatch`/`WatchMessageFromWatch` plus
`pack`/`unpack`). Both sides of a new message must be added there.

## Conventions

- **Do not write comments or docstrings.** The one exception is the docstring on system test case classes;
  see `tests/AGENTS.md`.
- **Magic numbers are fine, and often preferred, when used in a single place.** Do not hoist a literal
  into a named constant just because it is a literal — only name it when the same value is used in more
  than one place.
- `swiftformat` at 110 columns, Swift 5.9 mode, `--disable docComments --ifdef no-indent`.
- `swiftlint --strict`. Many rules are off (see `.config/swiftlint.yml`) — notably `force_cast`, `force_try`,
  `identifier_name`, `cyclomatic_complexity` and `function_body_length`, so long `switch`-heavy functions
  and `try!` are idiomatic here.
- All user-facing strings go through `String(localized:)` and live in `Common/Localizable.xcstrings` —
  never `.strings` files. `utils/xcstringslint.py` (part of `just lint`) checks that format specifiers
  match across translations and that multi-specifier strings use positional `%1$@` forms.
- `Moblin/Integrations/Tesla/Protobuf/` is generated and excluded from formatting and periphery.
- `Moblin/RemoteControl/Web/` is build output — edit `WebRemoteControlFrontend/` instead (see its
  `AGENTS.md`).
- Code shared between the app, watch, and extensions goes in `Common/`.
- The `moblin://?<url-encoded JSON>` settings import format is defined by `MoblinSettingsUrl.swift`; its
  members are the JSON keys, and the README documents it for users.

## Reporting

- Never mention the StoreKit.framework change in `Moblin.xcodeproj/project.pbxproj` in summaries, reviews or
  commit messages.
- Never mention styling or formatting changes (swiftformat, oxfmt, isort, ruff format output) in summaries, reviews
  or commit messages.
