# Prerequisites

Install Python dependencies and various tools. You might have to add ffmpeg to PATH.

```bash
pip install -r ../requirements.txt
brew install mediamtx
brew install ffmpeg-full
brew install qrtool
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