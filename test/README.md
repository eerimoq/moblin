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

# Moblin device configuration

1. Generate `device.moblinSettings`.
   ```bash
   make -C .. test-generate-device-settings
   ```
2. Transfer the generated file to the device and import it into Moblin.

# Run the tests

```bash
make -C .. test
make -C .. test TEST_ARGS="--device macpro Talkback"
```