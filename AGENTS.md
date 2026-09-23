# Repository guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) for architecture, conventions, and
validation commands. These instructions cover work in this repository.

## Before editing

- Read the closest complete feature path: settings, view, model methods, runtime
  implementation, callers, and tests. Prefer the established owner and helper.
- Extend the relevant `Model` feature file. Keep shared setup and adjacent small
  setters together; a new method does not require a new file or abstraction.
- Check the actual source, [justfile](justfile), formatter configuration, and
  [CI workflow](.github/workflows/all.yml) before relying on remembered rules.

## While editing

- Keep platform operations and capability checks beside related platform
  extensions. Use the caller's existing configuration lock and execution path.
- For settings, check defaults, coding keys, encoding, decoding, cloning, and
  applicable import/export paths. Wire initial setup as well as later changes.
  Preserve persisted keys and enum raw values.
- Route controls through existing model operations so local, remote, shortcut,
  and watch state stays consistent. Preserve each setting's apply/reload timing.
- Match the existing observable state objects and SwiftUI controls. Include new
  labels in the appropriate string catalog.
- Trace queue and actor ownership before changing synchronization. Reuse the
  existing timer and network helpers. Unsafe isolation annotations do not make
  shared state safe.
- Follow both supported rendering paths and scene attachment behavior when
  changing effects. Check both ends and target membership for shared protocols.
- Edit frontend source and regenerate its bundled assets. Follow the generation
  instructions for protobuf files.

## Before finishing

- Use focused tests of the production behavior and the relevant recipes in
  `CONTRIBUTING.md`. Run Swift unit tests with Mac Catalyst; CI does not run them.
- Device suites require a configured test setup and a running application.
  Their setup and cleanup can change settings and recordings.
- Review the diff for completeness and local style. Report actual commands,
  results, and unavailable checks. Distinguish source validation from an Xcode
  build and device behavior.
