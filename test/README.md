# Prerequisites

1. `pip install -r ../requirements.txt`
2. Install mediamtx.
3. Install ffmpeg (`brew install ffmpeg-full`) and add it to PATH.

# Moblin device configuration

1. Generate settings with `make -C .. test-generate-device-settings`.
2. Import the generated settings into Moblin.

# Run the tests

`make -C .. test`

`make -C .. test TEST_ARGS="--device macpro Talkback"`