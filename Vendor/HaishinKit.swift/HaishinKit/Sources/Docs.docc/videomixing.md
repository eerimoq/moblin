# Video mixing
HaishinKit provides APIs for overlaying still images on camera footage and for embedding text. These features are collectively referred to as [ScreenObjects](https://docs.haishinkit.com/swift/latest/documentation/haishinkit/screenobject).
Filtering with CIFilter is also supported, and for use cases such as applying a mosaic effect to camera footage, the use of CIFilter is recommended.

## Usage
Here is an overview of how to use the typical ScreenObject objects.

### ImageScreenObject
An example of compositing images.
```swift
let imageScreenObject = ImageScreenObject()
let imageURL = URL(fileURLWithPath: Bundle.main.path(forResource: "game_jikkyou", ofType: "png") ?? "")
if let provider = CGDataProvider(url: imageURL as CFURL) {
  imageScreenObject.verticalAlignment = .bottom
  imageScreenObject.layoutMargin = .init(top: 0, left: 0, bottom: 16, right: 0)
  imageScreenObject.cgImage = CGImage(
    pngDataProviderSource: provider,
    decode: nil,
    shouldInterpolate: false,
    intent: .defaultIntent
  )
} else {
  print("no image")
}

try? await mixer.screen.addChild(imageScreenObject)
```

### VideoTrackScreenObject
There may be situations where you want to capture the scenery with the rear camera while showing your facial expression with the front camera.

First, set up the cameras as follows. Make sure to remember the track numbers, as they will be used later.
```swift
Task {
  let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
  try? await mixer.attachVideo(back, track: 0)
  let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
  try? await mixer.attachVideo(front, track: 1)
}
```

Track number 0 is designed to be rendered across the entire screen. In this case, we are specifying where to render track number 1.

```swift
Task { @ScreenActor in
  let videoScreenObject = VideoTrackScreenObject()
  videoScreenObject.cornerRadius = 32.0
  videoScreenObject.track = 1
  videoScreenObject.horizontalAlignment = .right
  videoScreenObject.layoutMargin = .init(top: 16, left: 0, bottom: 0, right: 16)
  videoScreenObject.size = .init(width: 160 * 2, height: 90 * 2)
  // You can add a CIFilter-based filter using the registerVideoEffect API.
  _ = videoScreenObject.registerVideoEffect(MonochromeEffect())

  try? await mixer.screen.addChild(videoScreenObject)
}
```
