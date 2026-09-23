# Contributing

Start with the feature's existing implementation. Follow its settings, view,
model methods, media or integration code, and tests before choosing where to
change it. A contribution should fit the surrounding code without introducing
a second way to configure or control the same behavior.

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
changing a shared operation. Updating one view can otherwise leave remote state,
quick buttons, or watch state behind.

Read the neighboring code for when a setting takes effect. Some changes apply
immediately; others require camera attachment, stream reload, or restart. Wire
both initial setup and subsequent changes through the existing lifecycle.
Do not introduce polling, observers, or another copy of the setting merely to
apply it sooner.

## Swift conventions

- Match nearby names, argument labels, access control, and declaration order.
  Keep the feature's existing type and file naming. Small private types and
  helpers commonly stay in the file that uses them.
- Prefer direct assignments, early `guard` exits, and ordinary `switch`
  statements. Add an intermediate value, wrapper, or extra condition when it
  expresses necessary behavior. A literal used once does not automatically need
  a named constant; name values when their meaning or reuse warrants it.
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
  Disabled lint rules are not an invitation to refactor surrounding code or to
  introduce avoidable forced casts and unwraps.

## Persisted settings and compatibility

Settings classes commonly implement `Codable` by hand. A new persisted property
needs its declaration and default, `CodingKeys` entry, encoder entry, and decoder
entry. Use the keyed container helpers in
[CommonUtils.swift](Common/Various/CommonUtils.swift). They provide defaults for
missing or undecodable values and an overload for value validation.

Keep construction and decoding defaults consistent unless compatibility requires
otherwise. Check the containing type's `clone()` and any import, export, or
settings-URL representation that should carry the value. Merely adding
`@Published` does not make a property persist or apply it to running media.

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
fits. Match comparable debug-setting plumbing, but evaluate synchronization
from actual access patterns. Neither `nonisolated(unsafe)` nor
`@unchecked Sendable` provides synchronization. Do not add or remove a lock just
to imitate a nearby declaration.

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

Review the complete diff for feature ownership, settings compatibility,
localization, affected callers, and generated assets. Keep unrelated cleanup
and dependency changes separate.

Describe the concrete problem and resulting behavior. Report exact validation
commands and results, plus any unavailable checks. Camera, audio, Bluetooth,
network bonding, and performance claims need appropriate device evidence;
local source checks cannot establish them. Do not present untested behavior as
verified.
