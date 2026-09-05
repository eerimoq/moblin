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

# Traffic shaping

The stability test can simulate bad networks, with separate impairments for the outgoing
stream and the ingests. Shaping is done by a separate Linux machine placed in the media
path. It relays the media with `socat` and shapes it with `tc netem`, both controlled over
SSH by the test machine. The remote control connection between the device and the test
machine is never shaped.

```
 device (Moblin)                shaper (Linux)                 tester
      |                                |                          |
      |  stream  srt :8890 ----------->| socat udp 8890 --------->| ffmpeg
      |<---------------- rtmp :11935 --| socat tcp 11935 <--------| ffmpeg
      |<----------------- srt :4000 ---| socat udp 4000 <---------| ffmpeg
      |<---------------- rist :6500 ---| socat udp 6500 <---------| ffmpeg
      |  whep :8889 and :8189 -------->| socat tcp 8889, udp 8189 |
      |                                                           |
      |========== remote control, never shaped ===================|
```

## Traffic shaper machine configuration

1. Install the dependencies.
   ```bash
   sudo apt install socat iproute2
   ```
2. Allow the test machine to log in with an SSH key without a password.
3. Allow passwordless sudo, for example by adding the following line with `sudo visudo`.
   ```
   erik ALL=(ALL) NOPASSWD: ALL
   ```
4. Add the machine to `tests/config.toml`.
   ```toml
   [shaper]
   user = "erik"
   ip-address = "shaper.home"
   interface = "eth0"
   ```

The device may not be the test machine, as only traffic that transits the traffic shaper
can be shaped.
