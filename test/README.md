# Prerequisites

1. Install Python dependencies.
   ```bash
   pip install -r ../requirements.txt
   ```
2. Install mediamtx.
   ```bash
   brew install mediamtx
   ```
3. Install ffmpeg and add it to PATH.
   ```bash
   brew install ffmpeg-full
4. Install qrtool.
   ```bash
   brew install qrtool
   ```
   ```

# Moblin device configuration

1. Generate settings into clipboard.
   ```bash
   make -C .. test-generate-device-settings
   ```
2. Import the generated settings from clipboard into Moblin.

# Run the tests

```bash
make -C .. test
make -C .. test TEST_ARGS="--device macpro Talkback"
```