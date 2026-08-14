# Prerequisites

Install Python dependencies and various tools. You might have to add ffmpeg to PATH.

```bash
pip install -r ../requirements.txt
brew install mediamtx
brew install ffmpeg-full
brew install qrtool
brew install ltc-tools
```

# Configuration

Copy `config.example.toml` to `config.toml` and modify it to match your test setup.

```bash
cp config.example.toml config.toml
```

`config.toml` in this folder is used if it exists, otherwise
`$XDG_CONFIG_HOME/moblin/tests/config.toml`, where `$XDG_CONFIG_HOME` defaults to `~/.config`.

# Moblin device configuration

## Via clipboard

1. Generate settings into clipboard.
   ```bash
   make generate-device-settings-clipboard
   ```
2. Import the generated settings from clipboard into Moblin.

## Via standard output

1. Generate settings to standard output.
   ```bash
   make generate-device-settings-stdout
   ```
2. Import the generated settings somehow.

# Run the tests

```bash
make test
make test TEST_ARGS="--device macpro Talkback"
```

# Run the stability test

```bash
make stability
make stability TEST_ARGS="--device macpro --duration 0.5"
```

Give `--ingests` to select which ingests to stream to. All of `rtmp`, `srt`, `rist` and
`whep` are streamed to by default. The scene and its widgets are always configured for all
ingests, but the ingests that are not streamed to are disabled in the app.

```bash
make stability TEST_ARGS="--ingests rtmp"
make stability TEST_ARGS="--ingests srt,whep"
```

Give an empty list of ingests to only run the outgoing stream. All ingests are disabled in
the app.

```bash
make stability TEST_ARGS="--ingests ''"
```

Give `--no-stream` to only run the ingests. The app never goes live, and everything
related to the outgoing stream is left unmonitored and unrecorded.

```bash
make stability TEST_ARGS="--no-stream"
```

Everything is recorded to disk in the app while the test runs. The recording is downloaded to
`files/stability-recording.mp4` and deleted from the device when the test ends, also when it
fails. Make sure the device has enough free disk space, as roughly 2.5 GB is recorded per hour.
Give `--no-record` to not record at all.

```bash
make stability TEST_ARGS="--no-record"
```

The outgoing stream is received by `ffmpeg`, which listens for SRT connections on the test
machine, and everything it receives is written to `files/stability-stream-1.ts`. A new file,
with the number increased by one, is created if `ffmpeg` exits and is restarted, typically
because the app reconnected. Make sure the test machine has enough free disk space, as
roughly 2.3 GB is written per hour at the default bitrate. All files are deleted when the
next test run starts.

# Watch the stability test

Show all graphs at once in a grid, updated live while the stability test is running. Two
columns are used if the terminal is wide enough, otherwise one. Press `h` for help, and `q`
to quit.

```bash
make stability-watch
```

Show a single graph, with the same keys.

```bash
python watch.py ram
python watch.py cpu
python watch.py video-decode-errors
python watch.py duplicated-frames
python watch.py dropped-frames
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
4. Add the machine to `config.toml`.
   ```toml
   [shaper]
   user = "erik"
   ip-address = "shaper.home"
   interface = "eth0"
   ```

The device may not be the test machine, as only traffic that transits the traffic shaper
can be shaped.

## Run the stability test with traffic shaping

Give `--stream-traffic-shaping-profile` and `--ingests-traffic-shaping-profile` to shape the
outgoing stream and the ingests, and `--stream-traffic-shaping-parameters` and
`--ingests-traffic-shaping-parameters` to configure the profiles. The stream and the ingests
are optional and independent of each other. Adaptive bitrate is enabled
automatically when the outgoing stream is shaped, and the expected bitrates are derived
from the given rates.

```bash
make stability TEST_ARGS="--stream-traffic-shaping-profile constant --stream-traffic-shaping-parameters rate=3Mbit,delay=60,loss=0.5"
make stability TEST_ARGS="--ingests-traffic-shaping-profile constant --ingests-traffic-shaping-parameters rate=12Mbit,jitter=10,delay=40"
make stability TEST_ARGS="--stream-traffic-shaping-profile square --stream-traffic-shaping-parameters low-rate=1Mbit,high-rate=8Mbit,period=90"
make stability TEST_ARGS="--stream-traffic-shaping-profile random --stream-traffic-shaping-parameters min-rate=1Mbit,max-rate=10Mbit,interval=15,seed=1"
```

The profiles are `constant`, `square` and `random`. The parameters are given as a comma
separated list of `<name>=<value>` pairs.

| Parameter | Profiles | Description |
|---|---|---|
| `delay` | all | One way delay in milliseconds. |
| `jitter` | all | Delay variation in milliseconds. |
| `loss` | all | Packet loss in percent. |
| `limit` | all | Queue length in packets (default 1000). |
| `rate` | constant | Bandwidth limit, for example `3Mbit`, `500kbit` or `3000000` (default 4Mbit). |
| `low-rate`, `high-rate` | square | Bandwidth limits to alternate between (`low-rate` defaults to 3Mbit). |
| `period` | square | Seconds at each rate (default 60). |
| `min-rate`, `max-rate` | random | Bandwidth limits to pick random rates between (defaults to 1Mbit and 7Mbit). |
| `interval` | random | Seconds between rate changes (default 15). |
| `seed` | random | Random seed for reproducible runs. |
