# ``HaishinKit``
メインモジュールです。

## 🔍 概要
ライブストリーミングに必要なカメラやマイクのミキシング機能の提供を行います。各モジュールに対して共通の処理を提供します。

### モジュール構成
|モジュール|説明|
|:-|:-|
|HaishinKit|本モジュールです。|
|RTMPHaishinKit|RTMPプロトコルスタックを提供します。|
|SRTHaishinKit|SRTプロトコルスタックを提供します。|
|RTCHaishinKit|WebRTCのWHEP/WHIPプロトコルスタックを提供します。現在α版です。|
|MoQTHaishinKit|MoQTプロトコルスタックを提供します。現在α版です。

## 🎨 機能
以下の機能を提供しています。
- ライブミキシング
  - [映像のミキシング](doc://HaishinKit/videomixing)
    - カメラ映像や静止画を一つの配信映像ソースとして扱います。
  - 音声のミキシング
    - 異なるマイク音声を合成して一つの配信音声ソースとして扱います。
- Session
  - RTMP/SRT/WHEP/WHIPといったプロトコルを統一的なAPIで扱えます。

## 📖 利用方法
### ライブミキシング
```swift
let mixer = MediaMixer()

Task {
  do {
    // Attaches the microphone device.
    try await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
  } catch {
    print(error)
  }

  do {
    // Attaches the camera device.
    try await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back))
  } catch {
    print(error)
  }

  // Associates the stream object with the MediaMixer.
  await mixer.addOutput(stream)
  await mixer.startRunning()
}
```

### Session api.
RTMPやSRTとのクライアントとしての実装を統一的なAPIで扱えます。リトライ処理などもAPI内部で行います。

#### 前準備
```swift
import HaishinKit
import RTMPHaishinKit
import SRTHaishinKit

Task {
  await SessionBuilderFactory.shared.register(RTMPSessionFactory())
  await SessionBuilderFactory.shared.register(SRTSessionFactory())
}
```

#### Sessionの作成
```swift
let session = try await SessionBuilderFactory.shared.make(URL(string: "rtmp://hostname/live/live"))
  .setMode(.ingest)
  .build()
```
```swift
let session = try await SessionBuilderFactory.shared.make(URL(string: "srt://hostname:448?stream=xxxxx"))
  .setMode(.playback)
  .build()
```

#### 接続
配信や視聴を行います。
```swift
try session.connect {
  print("on disconnected")
}
```

