# FAQ
Frequently Asked Questions and Answers from a Technical Perspective.

## Q. Is it possible to use a UVC camera?
Yes. Starting with iPadOS 17.0, it became available through [the OS API](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/external). Unfortunately, its operation on iOS has not been confirmed.
```swift
if #available(iOS 17.0, *) {
  let camera = AVCaptureDevice.default(.external, for: .video,
position: .unspecified)
  try? await mixer.attachVideo(camera, track: 0)
}
```
