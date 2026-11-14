# System tests

A Python harness (`systest`) that drives a real Moblin device over its remote control API against
`mediamtx`/`ffmpeg`. Setup and device configuration are in `README.md`. Not run in CI.

```sh
just test
just test --device macpro Talkback
just test-stability                        # long-running soak test, 12 hours by default
```

## Running

The app must be running on the device first. If the device is connected over USB, launch it yourself and
only ask the user if that fails (for example, because the device is locked):

```sh
xcrun devicectl list devices
xcrun devicectl device process launch --terminate-existing --device <UDID> com.eerimoq.Mobs
```

The bundle identifier is `BASE_PRODUCT_BUNDLE_IDENTIFIER` in `Config/User.xcconfig`. Test devices
(`macpro`, `ipadair`, …) are configured in `tests/config.toml`, or `$XDG_CONFIG_HOME/moblin/tests/config.toml`
if that does not exist.

## Module names

The harness runs with `tests/` as the working directory, so its imports are `from utils.moblin import
Moblin`, while `just lint` type checks `tests/` and `utils/` from the repo root. That only works while
every module name is unique across both trees — `tests/suites/` and `tests/utils/` are packages
(`__init__.py`) so that `tests/suites/stability.py` does not collide with the `tests/stability.py` entry
point. Adding a `utils/x.py` that shadows a `tests/x.py` (or dropping an `__init__.py`) makes mypy abort
with "Duplicate module named ..." instead of checking anything.

## Writing tests

- System tests only cover a few important end-to-end cases; broad coverage belongs in the unit tests in
  `MoblinTests/`. Before adding a system test step, check whether a unit test can cover it.
- Keep each suite within its time budget; the remote control scene config tests take at most 3-4 minutes
  in total.
- A test case class in `tests/suites/` gets a one-line docstring describing what the test does
  (`"""Play talkback sound over RTMP server through the speaker for 10 seconds."""`). This is the only
  exception to the root rule against comments and docstrings.
- Assert on observable state through the remote control API (`get_state()`, `get_music_status()`, …),
  never by watching Moblin's log (`add_log_entry_observer`).
- Never use a runnable test class (one with a docstring and `run`, instantiated in `tests()`) as the base
  of another test. Shared helpers go on a non-test base named `*TestCase` with no docstring and no `run`,
  and each test subclasses it directly with its own explicit `run`.
