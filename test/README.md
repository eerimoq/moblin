# Prerequisites

1. Install Python dependencies.
   ```bash
   pip install -r ../requirements.txt
   ```
2. Install mediamtx.
3. Install ffmpeg.
   ```bash
   brew install ffmpeg-full
   ```

# Moblin device configuration

1. Generate settings.
   ```bash
   make -C .. test-generate-device-settings
   ```
2. Import the generated settings into Moblin.

# Run the tests

```bash
make -C .. test
make -C .. test TEST_ARGS="--device macpro Talkback"
```