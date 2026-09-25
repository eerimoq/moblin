# Repository guidance

Follow [CONTRIBUTING.md](CONTRIBUTING.md). It defines the shared code conventions,
examples, and validation commands. Read the sections relevant to the task before
editing; a small change does not require reviewing the whole repository.

## Scope the change

- Identify the expected behavior and a focused way to verify it. Resolve
  ambiguity that affects stored data, protocol messages, or user-visible behavior
  before implementing it; state consequential assumptions.
- Trace the affected callers and existing owner. Reuse its helpers and lifecycle
  instead of adding a parallel control path or an abstraction for future use.
- Keep unrelated edits and formatting out of the diff. Remove code made unused
  by the change; leave unrelated cleanup separate.

## Read for the affected area

| Change | Contributor guidance |
| --- | --- |
| Swift code or feature placement | [Ownership](CONTRIBUTING.md#put-behavior-in-its-existing-owner) and [Swift conventions](CONTRIBUTING.md#swift-conventions). Small setters may stay in `Model.swift`; platform operations belong beside related extensions. |
| Settings | [Persistence and compatibility](CONTRIBUTING.md#persisted-settings-and-compatibility). Check defaults, keys, encoding, decoding, cloning, applicable import/export, and application at startup and on change. |
| Capture, effects, or shared state | [Concurrency and media](CONTRIBUTING.md#concurrency-and-media). Trace queue ownership, locks, cleanup, and the supported rendering paths. Unsafe isolation annotations do not synchronize access. |
| Views or labels | [UI and localization](CONTRIBUTING.md#ui-and-localization). Reuse observable state objects and controls; include labels in the appropriate catalog. |
| Protocols, companions, or web frontend | [Shared protocols and generated files](CONTRIBUTING.md#protocols-companion-targets-and-generated-files). Check both ends and target membership; edit source and regenerate bundled output. |

Match neighboring code and the formatter configuration. Keep shared controls on
the existing model operations so local, remote, and companion state stays
consistent.

## Verify and report

Use [Build and check a change](CONTRIBUTING.md#build-and-check-a-change) to select
checks for the changed behavior. The [justfile](justfile), formatter configuration,
and [CI workflow](.github/workflows/all.yml) are the command references; check them
when changing tooling or resolving a discrepancy in this guidance.

- Swift unit tests use Mac Catalyst. CI builds the app but does not run them.
- Device suites require a configured test setup and a running app. Setup and
  cleanup can change settings, start streams, and delete recordings; do not run
  them against a live streaming device.
- Review the final diff against the requested behavior and local conventions.
  Report actual commands, results, and unavailable checks. Source or syntax
  checks do not establish an Xcode build or device behavior.
