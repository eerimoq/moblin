# Insta360 GO Ultra prototype

This branch adds an experimental GO Ultra camera source to Moblin. It receives the camera's HEVC preview over Wi-Fi and feeds decoded frames into Moblin's existing scene and streaming pipeline. It has not yet been validated with a physical GO Ultra. Luna cameras are not supported by this implementation.

## Setup

1. Build this branch using the development setup in the main README. A custom build must be installed through Xcode or distributed with appropriate Apple signing; this does not change the App Store version of Moblin.
2. Activate and update the camera using the official Insta360 app if needed. Note the firmware version for testing.
3. Connect the iPhone to the camera's Wi-Fi network, then close the Insta360 app so it does not hold the preview connection.
4. In Moblin, open Settings > Ingests > Insta360 GO Ultra. Allow Local Network access if prompted.
5. Leave the camera IP at `192.168.42.1` unless the camera uses another address. Enable the connection and wait for **Receiving video**.
6. Choose **Insta360 GO Ultra** as a scene's camera. Choose a phone or external microphone separately.
7. Use cellular data, Ethernet, or another available uplink for the outgoing stream. Check that the stream can reach its destination while Wi-Fi is connected to the camera.

The latency setting initially buffers 300 ms. It is not a measurement or guarantee of end-to-end delay. Disabling the input closes the connection and attempts to stop the preview. Connection failures and video stalls trigger retries with a delay of up to 15 seconds. The connection log uses the `insta360:` prefix.

## Installing on an iPhone

The first hardware test should use an Xcode development build. In the ignored `Config/User.xcconfig`, select your own Apple development team and a unique `BASE_PRODUCT_BUNDLE_IDENTIFIER`, such as `com.yourname.MoblinGoUltra`, and keep `CAPABILITIES = free` for the initial test. All companion targets derive their identifiers from that base. Using a separate identifier lets the test build coexist with the official app.

Connect the iPhone to the Mac, enable Developer Mode, select it as the run destination in Xcode, and build and run the Moblin scheme. Xcode may require signing in with your Apple account and selecting your team. The unsigned validation builds used during development cannot simply be installed as an IPA.

For repeat testing without Xcode, an Apple Developer Program team can create its own App Store Connect app record and upload a signed archive to TestFlight. This requires that team's signing and distribution setup; opening a GitHub PR does not deploy a build. Access to the upstream Moblin developer's TestFlight or App Store release is controlled by that maintainer. See [Apple's distribution guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

## Scope and limitations

- Video preview only; no camera audio, recording controls, Bluetooth discovery, automatic Wi-Fi joining, or Luna support.
- The preview resolution and frame rate are camera-controlled. Independent research reports 1080p30 on GO Ultra firmware v1.5.47; that is not a hardware result from this branch.
- Frames use reception time on the phone, with the configured buffer delay. Camera timestamps and audio synchronization remain to be validated.
- The protocol is unofficial. This is an independently written implementation of the framing described in the [GO Ultra protocol research](https://github.com/Daiki-Iijima/insta360-go-ultra-sdk/blob/main/docs/protocol.md). The [official GO SDK documentation](https://insta360develop.github.io/Insta360-Developer_Docs/en/go/) currently lists iOS support as planned.
- Receiving this source in Moblin does not expose it as a system camera to other iPhone apps.

## Hardware acceptance checks

- Confirm handshake and a decoded live picture on the specific firmware. A TCP connection alone must not show **Receiving video**.
- Confirm the source survives switching scenes, settings reload, disabling/re-enabling, and camera power cycling.
- Confirm the image orientation, crop, frame rate, colors, stabilization, and visible delay with a moving subject or filmed timer.
- Stream for at least 30 minutes while monitoring phone/camera temperature, battery, stalls, and memory.
- Test phone/external microphone synchronization and adjust Moblin's microphone delay if needed.
- Verify cellular upload continues while the iPhone is on the camera's Wi-Fi.
- Confirm disabling the input stops reconnect attempts and allows the official app to reconnect.
