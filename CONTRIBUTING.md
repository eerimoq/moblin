# Contributing

Start with the behavior you want to change and the closest existing feature.
Trace the affected settings, controls, model methods, runtime code, and tests.
Reuse that path and keep unrelated cleanup out of the change.

For setup and commands, see [Build and check a change](#build-and-check-a-change).
The sections below explain conventions that are easy to miss when working on
only one part of the application. Use the sections relevant to your change.

## How the application fits together

The application captures, composes, encodes, streams, and records live media.
Scenes select video sources and arrange widgets and effects. Streaming,
recording, preview, remote control, and companion devices share parts of that
pipeline, so a change to one entry point can affect several outputs.

| Area | Responsibility |
| --- | --- |
| [Application entry point](Moblin/MoblinApp.swift) | Owns the main model and connects application and scene lifecycle events. |
| [Settings](Moblin/Various/Settings/) | Persisted configuration, defaults, decoding, cloning, and migrations. |
| [Model](Moblin/Various/Model/) | Runtime state and coordination, split into feature extensions of `Model`. |
| [Views](Moblin/View/) | SwiftUI screens and controls, with shared components in [View/Utils](Moblin/View/Utils/). |
| [Media facade](Moblin/Various/Media.swift) and [media implementation](Moblin/Media/) | Capture, encoding, recording, transport, ingest, and adaptive bitrate. The embedded media implementation is maintained source. |
| [Video effects](Moblin/VideoEffects/) | Scene composition and rendering through Core Image and MetalPetal. |
| [Integrations](Moblin/Integrations/), [streaming platforms](Moblin/StreamingPlatforms/), and [OBS control](Moblin/Obs/) | Device protocols, service clients, chat, events, and external control. |
| [Remote control](Moblin/RemoteControl/) and [Moblink](Moblin/Moblink/) | Control messages and state exchange; network sharing through relay connections. These are separate protocols. |
| [Common](Common/) and companion directories | Shared utilities and localization; watch, widget, live activity, screen recording, and desktop support. Some target-specific shared code lives in each companion's `Shared` directory. |
| [Web frontend](WebRemoteControlFrontend/) | SolidJS, TypeScript, and CSS for the pages served by the application. |
| [Unit tests](MoblinTests/), [system tests](tests/), and [utilities](utils/) | Swift Testing suites, device-driven Python tests, and development tools. |

## Put behavior in its existing owner

Extend the relevant `Model` feature extension. Shared setup and small setters
already grouped in `Model.swift` can stay there. Add a file when it represents a
separate feature area, not merely because a method is new.

Views bind to settings and observable runtime state, then call model methods to
apply changes. Keep hardware operations and protocol handling in the existing
media, integration, or utility layer. Put operations on platform types beside
related extensions, such as those in [CameraUtils.swift](Moblin/Various/Utils/CameraUtils.swift).
Capability and availability checks belong beside the platform operation; the
caller retains responsibility for its configuration lock and execution context.

Use the same model operations from local controls, remote requests, shortcuts,
and companion messages. Check their callers and state notifications before
changing a shared operation.

For example, a control that selects a scene should call the operation in
[ModelScene.swift](Moblin/Various/Model/ModelScene.swift).

Bad: changing only the selected identifier bypasses the scene switch.

```swift
model.sceneSelector.selectedSceneId = scene.id
```

Good: the shared operation also updates the camera, microphone, remote state,
and local watch state as needed.

```swift
model.selectScene(id: scene.id)
```

Read the neighboring code for when a setting takes effect. Some changes apply
immediately; others require camera attachment, stream reload, or restart. Wire
both initial setup and subsequent changes through the existing lifecycle.
Do not introduce polling, observers, or another copy of the setting merely to
apply it sooner.

### Keep platform details in the existing helper

Bad: repeating a device capability check in capture setup.

```swift
if device.isLowLightBoostSupported {
    device.automaticallyEnablesLowLightBoostWhenAvailable = nativeLowLightBoost
}
```

Good: use the existing operation beside the other camera configuration calls.

```swift
device.setLowLightBoost(value: nativeLowLightBoost)
```

The helper in [CameraUtils.swift](Moblin/Various/Utils/CameraUtils.swift) keeps
the support check with the platform operation:

```swift
func setLowLightBoost(value: Bool) {
    guard isLowLightBoostSupported else {
        return
    }
    automaticallyEnablesLowLightBoostWhenAvailable = value
}
```

This method belongs to the existing `AVCaptureDevice` extension. Its caller in
[VideoCaptureSession.swift](Moblin/Media/HaishinKit/Media/Video/VideoCaptureSession.swift)
already holds the configuration lock. The helper does not acquire that lock.

## Swift conventions

- Match nearby names, argument labels, access control, and declaration order.
  Keep the feature's existing type and file naming. Small private types and
  helpers commonly stay in the file that uses them.
- Prefer direct assignments, early `guard` exits, and ordinary `switch`
  statements. Reuse existing helpers before adding a wrapper, protocol, manager,
  or dependency. Introduce an abstraction when the change needs it, not for
  possible future callers. Name constants when their meaning or reuse warrants it.
- Keep comments sparse and limited to non-obvious intent, protocol constraints,
  or calculations. Avoid summaries of the code, change history, and boilerplate
  documentation. System test classes use docstrings to describe the scenario.
- Use the existing `ObservableObject`, `@Published`, `@ObservedObject`, and
  `@EnvironmentObject` patterns. Frequently updated state is often held in small
  observable objects such as `Bitrate`, `Battery`, and `StreamOverlay`; observe
  the relevant object rather than broadening updates to the whole model.
- Follow [.config/swiftformat](.config/swiftformat) and
  [.config/swiftlint.yml](.config/swiftlint.yml). The formatter uses 110 columns
  and Swift 5.9 formatting mode; the Xcode targets compile in Swift 6 mode.
  Match the surrounding style without reformatting unrelated code. A disabled
  lint rule does not make a forced cast or unwrap safe for untrusted input.

## Persisted settings and compatibility

Settings classes commonly implement `Codable` by hand. A new persisted property
needs its declaration and default, `CodingKeys` entry, encoder entry, and decoder
entry. Use the keyed container helpers in
[CommonUtils.swift](Common/Various/CommonUtils.swift). They provide defaults for
missing or undecodable values and an overload for value validation.

Bad: requiring a newly added key rejects older settings that lack it.

```swift
nativeLowLightBoost = try container.decode(Bool.self, forKey: .nativeLowLightBoost)
```

Good: [SettingsDebug.swift](Moblin/Various/Settings/SettingsDebug.swift) uses the
same default as a newly constructed settings object.

```swift
nativeLowLightBoost = container.decode(.nativeLowLightBoost, Bool.self, false)
```

These are decoder excerpts. The good line still needs the property, coding key,
and encoder entry; it does not replace the rest of the persistence work.

Check the containing type's `clone()` and any import, export, or settings-URL
representation that should carry the value. Merely adding `@Published` does not
make a property persist or apply it to running media. Wire initial setup and
later changes, preserving when the setting takes effect.

Persisted enum raw values, coding keys, and identifiers are compatibility
contracts. Localized display names belong in `toString()` or the view. Retain
the existing migration handling when changing stored meaning or structure;
see [Settings.swift](Moblin/Various/Settings/Settings.swift) and the affected
type's decoder. Do not add a migration for a field whose decoding default
already handles older settings.

Use the existing settings storage and Keychain paths for authentication tokens.
Check what the relevant import or export includes before changing it.

## Concurrency and media

`Model` and many control clients use `@MainActor`. Media work also uses dedicated
queues, including `processorControlQueue` and `processorPipelineQueue` in
[Processor.swift](Moblin/Media/HaishinKit/Media/Processor.swift). Trace the writer,
reader, callback queue, and start/stop order of any shared state you change.

Reuse [MainTimer](Moblin/Various/MainTimer.swift),
[SimpleTimer](Moblin/Various/SimpleTimer.swift), the existing network clients,
and [Atomic](Moblin/Media/HaishinKit/Util/Atomic.swift) where their ownership model
fits. Evaluate synchronization from actual access patterns. Neither
`nonisolated(unsafe)` nor `@unchecked Sendable` provides synchronization.

Keep device configuration within the established locking path. Preserve
delegate cleanup, timer cancellation, task cancellation, and restart behavior.
Keep blocking I/O and extra per-frame work out of capture and rendering paths.
Use existing buffer, timestamp, and packet helpers, and check malformed or
truncated input at protocol boundaries.

For scene widgets, follow the type and settings in
[SettingsScene.swift](Moblin/Various/Settings/SettingsScene.swift), construction
and ordering in [ModelScene.swift](Moblin/Various/Model/ModelScene.swift), the
widget editor and wizard, and the effect implementation. Preserve supported
rendering paths: shared effects have `execute` and `executeMetalPetal` methods;
effects that require MetalPetal use the existing `isMetalPetal()` selection.
Check scene switches, orientation, and source attachment as well as a steady
frame.

## UI and localization

Reuse `Form`, `Section`, navigation, and the controls in
[View/Utils](Moblin/View/Utils/). Check existing validation and submission
behavior before replacing an editor or picker. Preserve disabled, empty, error,
and disconnected states, accessibility, and portrait and landscape behavior.

SwiftUI controls accept localized string literals. Use `String(localized:)`
when a localized `String` is needed outside those APIs. Include new application
labels in [Common/Localizable.xcstrings](Common/Localizable.xcstrings) and check
the relevant target's catalog for companion-only strings. Preserve format
specifiers and positional arguments in translations. Run the existing catalog
lint; do not replace string catalogs with a parallel localization mechanism.

## Protocols, companion targets, and generated files

Remote requests and responses are defined in
[RemoteControl.swift](Moblin/RemoteControl/RemoteControl.swift). Follow a change
through encoding, decoding, dispatch, the model delegate, response, and state
events. Preserve existing message shapes and authentication. The web control
server has its own messages in
[RemoteControlWeb.swift](Moblin/RemoteControl/RemoteControlWeb.swift); update its
TypeScript counterparts when needed.

Watch messages use [WatchProtocol.swift](<Moblin Watch/Shared/WatchProtocol.swift>).
Screen recording exchanges buffers through the code in
[its Shared directory](<Moblin Screen Recording/Shared/>). Check both ends of a
shared message and the targets that compile the file. The Xcode project uses
synchronized folders with membership exceptions; do not add build-file entries
mechanically.

Edit web pages in `WebRemoteControlFrontend/` and reuse its SolidJS components
and utilities. Regenerate the bundled pages, JavaScript, and CSS under
`Moblin/RemoteControl/Web/` with the frontend build recipe. Include the resulting
asset changes; CI rebuilds them and checks for a clean diff.

Generated protobuf files under the device integration directories have their
own generation instructions. Follow those instructions when regeneration is
needed. The formatter excludes those directories. Avoid hand-editing generated
code or bundled frontend output.

## Build and check a change

Follow [development setup](README.md#development-environment-setup) for Xcode,
local configuration, and dependencies. Keep `Config/User.xcconfig` local. The
[justfile](justfile) and [CI workflow](.github/workflows/all.yml) define the
commands; prefer them over remembered tool invocations.

Choose checks for the changed files and behavior. A documentation edit needs
link and command checks; it does not require device tests. For a behavior change,
start with a focused check that would catch the defect, then run the relevant
repository checks:

```sh
just style-check
just lint
just spell-check
```

`just style` rewrites files. Scope formatting to the change when the working
tree contains unrelated work. Python uses isort and Ruff formatting; web source
uses oxfmt. The lint recipe also runs SwiftLint, oxlint, pylint, Ruff, mypy, and
the string catalog check.

For frontend changes:

```sh
just web-remote-control-frontend-prepare
just web-remote-control-frontend-build
```

The build recipe type-checks TypeScript before running Vite. Review the generated
diff and verify that another build introduces no further changes.

The application build used by CI is:

```sh
xcodebuild -scheme Moblin -skipPackagePluginValidation build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Unit tests use Swift Testing: `struct ...Suite`, `@Test`, and `#expect` under
`MoblinTests/`, usually mirroring the source directories. Extend the nearest
suite with a focused behavioral regression when the change needs one. Exercise
the production implementation, including persistence or malformed-input cases
when relevant. Keep timing and shared state deterministic.

Run unit tests with Mac Catalyst:

```sh
xcodebuild test -scheme Moblin \
    -destination 'platform=macOS,variant=Mac Catalyst'
```

The CI workflow builds the application but does not run these tests. A formatter
pass or standalone syntax check does not establish that the application builds
or the test target passes.

Device-driven tests live in `tests/suites/`. Reuse their `TestCase`, capability
checks, and setup/teardown paths. Run `just test` from the repository root; it
invokes `python -m tests.test`. Preserve package-relative imports. Follow
[tests/README.md](tests/README.md) to select and configure a test device and have
the app running before executing a suite. These tests can change device
settings, start streams, and delete recordings, so use a designated test setup.
`just test-stability` is a separate long-running test.

## Before submitting

Keep each pull request focused on one problem. Review the diff for feature
ownership, compatibility, localization, affected callers, and generated assets
where applicable. Remove helpers or imports your change made unused, and keep
unrelated cleanup and dependency changes separate.

Describe the concrete problem and resulting behavior. Report exact validation
commands and results, plus any unavailable checks. Camera, audio, Bluetooth,
network bonding, and performance claims need appropriate device evidence;
local source checks cannot establish them. Do not present untested behavior as
verified.
