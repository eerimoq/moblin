# Contribution guidance

Scope: document the existing architecture and contribution conventions. Preserve
application changes already present in the working tree.

Acceptance: inventory every tracked source area, compare the submitted and
accepted implementations, check guidance against source and build configuration,
and validate documentation links, formatting, and the final diff.

- [x] Survey all source areas and trace representative feature paths.
- [x] Compare the submitted implementation with the accepted implementation.
- [x] Write contributor guidance and a concise repository instruction file.
- [x] Validate the documentation and confirm unrelated files are unchanged.

## Review coverage

The local source survey used revision
`b257a2a91d0cbe1927c6d96448e0e4d96c0f5598` with the existing working tree changes.
It covered all 916 tracked Swift, Python, TypeScript, JavaScript, Metal, HTML,
and CSS files: 199,714 lines, including generated source and bundled web output.
All files were included in the structural and convention analysis. Detailed
reading followed application setup, settings persistence, camera configuration,
zoom and scene changes, rendering, protocol dispatch, companion messages, and
the unit and system test harnesses. The existing untracked Swift test file was
reviewed separately: another 93 lines, for 917 source files in total. This is a
contribution-convention review, not a claim that every function has been checked
for correctness.

| Source area | Files | Lines |
| --- | ---: | ---: |
| Shared utilities and views | 10 | 1,516 |
| Companion targets | 22 | 3,204 |
| Application entry point and intents | 5 | 211 |
| Settings, model, utilities, and media facade | 149 | 44,306 |
| Application views | 311 | 47,020 |
| Media implementation and transports | 131 | 22,326 |
| Video effects and shaders | 66 | 11,310 |
| Device and service integrations | 42 | 32,382 |
| Streaming platforms | 16 | 5,931 |
| External broadcast control | 1 | 1,086 |
| Remote control and bundled web source | 26 | 3,201 |
| Network sharing | 4 | 1,110 |
| Swift unit tests | 63 | 9,004 |
| Web frontend | 20 | 4,335 |
| System tests and supporting source | 43 | 12,135 |
| Development utilities | 7 | 637 |

## Accepted implementation comparison

Compared [the submitted change](https://github.com/eerimoq/moblin/pull/522) with
[the accepted implementation](https://github.com/eerimoq/moblin/commit/1c08f26957490d5f1f132d4b068bbc95598fa487).
The accepted revision is not present in the local checkout; its patch was read
directly from the upstream repository.

The accepted implementation moved capability checking and the device write into
the existing camera utility extension, used the adjacent debug flag and setter
shape, and included the label in the localization catalog. It retained the
persisted default and the setup/change wiring. The submitted test was not in
the accepted patch. The discussion gives no design rationale beyond a merge
acknowledgement, so these are observations of the diff, not a general rule to
remove tests, locks, or guards.

The prevention rule is to follow the complete existing feature path and put
each operation beside its related implementation. This is captured in
[the contributor guide](../CONTRIBUTING.md) without a historical walkthrough or
an invented example.

## Documentation decisions

- Keep shared conventions in `CONTRIBUTING.md` and a short execution checklist
  in the repository instruction file. Replace the old local guide with links
  so its stale claims cannot compete with current guidance.
- Correct the Python formatter and module invocation, distinguish Swift
  compiler mode from formatter mode, and describe SwiftUI localization
  accurately.
- Preserve Mac Catalyst unit testing and explain that CI builds without running
  the unit suite. Distinguish source checks, application builds, and device proof.
- Describe supported effect backends and explicit MetalPetal-only routing.
  Avoid claiming that every effect implements both backends or that all shared
  target code lives in one directory.

## Validation

- Standard-library documentation checks passed: 45 local links, heading anchors,
  balanced fences, final newlines, and no trailing whitespace or non-ASCII text.
  All four shell blocks passed `bash -n`; all five documented `just` invocations
  name existing recipes. Twelve architecture and tooling assertions matched
  their current source or configuration.
- `git diff --check -- CLAUDE.md` passed with exit 0. The equivalent new-file
  checks, `git diff --no-index --check -- /dev/null AGENTS.md` and the same
  command for `CONTRIBUTING.md` and `tasks/todo.md`, emitted no diagnostics.
  Their exit 1 denotes the added file in a no-index comparison.
- The local Unicode and metadata service inspected all four Markdown files
  without findings. Cleaning returned identical bytes; no rewrite was applied.
- SHA-256 checks confirmed all 11 pre-existing modified or untracked files were
  unchanged. Only the four documentation files were added or edited. Global
  guidance was untouched.

Xcode builds, Swift unit tests, and device tests were not run for this
documentation change. Xcode is unavailable on this host. The repository task
runner, SwiftLint, oxfmt, and codespell are also unavailable; their recipes were
verified against source, not reported as executed. No application behavior or
hardware performance is claimed from these checks.
