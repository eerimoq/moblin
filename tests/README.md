All commands below are run from the repository root.

# Prerequisites

Install Python dependencies and various tools. You might have to add ffmpeg to PATH.

```bash
pip install -r requirements.txt
brew install mediamtx ffmpeg-full qrtool ltc-tools
```

# Configuration

Copy `tests/config.example.toml` to `tests/config.toml` and modify it to match your test
setup.

```bash
cp tests/config.example.toml tests/config.toml
```

`tests/config.toml` is used if it exists, otherwise `$XDG_CONFIG_HOME/moblin/tests/config.toml`.

# Moblin device configuration

## Via clipboard

1. Generate settings into clipboard.
   ```bash
   just test-generate-device-settings-clipboard
   ```
2. Import the generated settings from clipboard into Moblin.

## Via standard output

1. Generate settings to standard output.
   ```bash
   just test-generate-device-settings-stdout
   ```
2. Import the generated settings somehow.

# Run the tests

```bash
just test --device macpro
just test --device macpro Talkback
```

# Run the stability test

```bash
just test-stability --device macpro
just test-stability --device macpro --duration 0.5
```

# Watch the stability test

```bash
python -m tests.watch grid
```

# Packet loss

The stability test always relays the UDP packets of the outgoing SRT or RIST stream and of
the SRT and RIST ingests through a lossy relay on the test machine, which drops some of them
in both directions. Adaptive bitrate is enabled for the relayed outgoing stream.
