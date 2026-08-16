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

# Watch the stability test

```bash
make stability-watch
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

Give `--stream-traffic-shaping` (`-s`) and `--ingests-traffic-shaping` (`-i`) to shape the
outgoing stream and each ingest. The stream and the ingests are optional and independent of
each other. Adaptive bitrate is enabled automatically when the outgoing stream is shaped,
and the expected bitrates are derived from the given rates.

```bash
make stability TEST_ARGS="-s constant,rate=3,delay=60,loss=0.5"
make stability TEST_ARGS="-i constant,rate=12,jitter=10,delay=40"
make stability TEST_ARGS="-s square,low-rate=1,high-rate=8,period=90"
make stability TEST_ARGS="-s random,min-rate=1,max-rate=10,interval=15,seed=1 -i constant,rate=3"
```

Both arguments are given as `<profile>,<name>=<value>,...`, where the profiles are
`constant`, `square` and `random`. All rates are in Mbps.

| Parameter               | Profiles | Description |
|-------------------------|----------|-------------|
| `delay`                 | all      | One way delay in milliseconds. |
| `jitter`                | all      | Delay variation in milliseconds. |
| `loss`                  | all      | Packet loss in percent. |
| `limit`                 | all.     | Queue length in packets (default 1000). |
| `rate`                  | constant | Bandwidth limit in Mbps (default 4). |
| `low-rate`, `high-rate` | square   | Bandwidth limits in Mbps to alternate between (`low-rate` defaults to 3 and `high-rate` to no limit). |
| `period`                | square   | Seconds at each rate (default 60). |
| `min-rate`, `max-rate`  | random   | Bandwidth limits in Mbps to pick random rates between (defaults to 1 and 7). |
| `interval`              | random   | Seconds between rate changes (default 15). |
| `seed`                  | random   | Random seed for reproducible runs. |
