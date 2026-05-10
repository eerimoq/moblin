# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Moblin is a free iOS/iPadOS IRL streaming app (Swift/SwiftUI) targeting Twitch, YouTube, Kick, Facebook, and OBS Studio. Includes an Apple Watch companion app, Live Activity extension, home screen widget, screen recording extension, and a SolidJS web remote control frontend.

## Building

1. Copy `User.template.xcconfig` → `Config/User.xcconfig`, set `DEVELOPMENT_TEAM` and `BASE_PRODUCT_BUNDLE_IDENTIFIER`.
2. `open Moblin.xcodeproj` — wait for SPM packages to resolve.
3. `Command + B` to build; `Command + R` to run on device.

Tests run via Xcode (`Command + U`). Test files live in `MoblinTests/` named `*Suite.swift`.

## Make targets

```sh
make style           # swiftformat + oxfmt (auto-fix)
make style-check     # lint-only, no writes
make lint            # swiftlint + oxlint + xcstringslint
make spell-check     # codespell
make periphery       # dead code detection

make web-remote-control-frontend-prepare   # npm install
make web-remote-control-frontend-build     # tsc check + vite build → embeds into Moblin/RemoteControl/Web/
```

Required tools: `swiftlint swiftformat periphery codespell oxfmt oxlint` (Homebrew).

## Key conventions

- `swiftformat` line width: 110 chars, Swift 5.9 mode.
- `swiftlint --strict`. Many rules disabled — see `.swiftlint.yml`. `force_cast` and `force_try` are disabled.
- Tesla Protobuf files (`Moblin/Integrations/Tesla/Protobuf/`) excluded from formatting and periphery.
- All localizations in `Common/Localizable.xcstrings` (not `.strings` files). Lint target: `xcstringslint`.
- `moblin://` URL scheme used for settings import — spec in README.

---

## Full codebase map

### Top-level targets

| Directory | Target |
|-----------|--------|
| `Moblin/` | Main iOS/iPadOS app |
| `Moblin Watch/` | watchOS companion |
| `Moblin Widget/` | Home screen widget |
| `Moblin Live Activity/` | Live Activity extension |
| `Moblin Screen Recording/` | Screen recording broadcast extension |
| `Common/` | Shared Swift + SwiftUI across all targets |
| `MoblinTests/` | Unit/integration tests |
| `WebRemoteControlFrontend/` | SolidJS web remote control |
| `Config/` | Xcode build configs (`*.xcconfig`) |
| `utils/` | Python utility scripts (translations, xliff, xcstringslint) |
| `docs/` | Documentation and screenshots |

---

### `Common/`

```
Localizable.xcstrings                  # All app strings / translations
Various/
  AudioLevel.swift
  AVAudioPCMBuffer+Extension.swift
  CMBlockBuffer+Extension.swift
  CMFormatDescription+Extension.swift
  CMSampleBuffer+Extension.swift
  CommonUtils.swift
  Validate.swift
View/
  StreamOverlayIconAndTextView.swift
  StreamOverlayTextView.swift
  ThermalStateView.swift
```

---

### `Moblin/` — Main app

#### Entry point
```
MoblinApp.swift                        # @main SwiftUI app entry
```

#### `Moblin/Various/Model/` — Central state (all @Observable extensions on Model)
```
Model.swift                            # Root @Observable class
ModelAppIntents.swift
ModelAppleWatch.swift
ModelAudio.swift
ModelAutoSceneSwitcher.swift
ModelBlackSharkCoolerDevice.swift
ModelBluetooth.swift
ModelCamera.swift
ModelCatPrinters.swift
ModelChat.swift
ModelChatBot.swift
ModelDisconnectProtection.swift
ModelDjiDevice.swift
ModelFaceBackgroundImage.swift
ModelGameController.swift
ModelGimbal.swift
ModelKeyboard.swift
ModelKick.swift
ModelLiveActivity.swift
ModelLocation.swift
ModelMacros.swift
ModelMediaPlayer.swift
ModelMoblink.swift
ModelNavigation.swift
ModelObs.swift
ModelPictureInPicture.swift
ModelRecording.swift
ModelRemoteControl.swift
ModelReplay.swift
ModelRistServer.swift
ModelRtmpServer.swift
ModelRtspClient.swift
ModelScene.swift
ModelScoreboard.swift
ModelScreenCapture.swift
ModelSettingsImportExport.swift
ModelSettingsUrl.swift
ModelSnapshot.swift
ModelSoop.swift
ModelSpeechToText.swift
ModelSrtlaServer.swift
ModelStealthMode.swift
ModelStore.swift
ModelStream.swift
ModelStreamWizard.swift
ModelTesla.swift
ModelTextToSpeech.swift
ModelTwitch.swift
ModelVideoPreview.swift
ModelWebBrowser.swift
ModelWhepClient.swift
ModelWhipServer.swift
ModelWiFiAware.swift
ModelWorkout.swift
ModelWorkoutDevice.swift
ModelYouTube.swift
ModelZoom.swift
Chat/
  ChatProvider.swift
```

#### `Moblin/Various/Settings/` — JSON-serializable persistent settings (separate from runtime state)
```
Settings.swift                         # Root settings object
SettingsAudio.swift
SettingsCatPrinter.swift
SettingsChat.swift
SettingsDebug.swift
SettingsDeepLinkCreator.swift
SettingsDjiDevice.swift
SettingsGameController.swift
SettingsGimbal.swift
SettingsGoPro.swift
SettingsIngests.swift
SettingsKeyboard.swift
SettingsLocation.swift
SettingsMacros.swift
SettingsMoblink.swift
SettingsNavigation.swift
SettingsQuickButtons.swift
SettingsRemoteControl.swift
SettingsScene.swift
SettingsSelfieStick.swift
SettingsStream.swift
SettingsTalkback.swift
```

#### `Moblin/Various/Storages/` — File-backed asset storage
```
AlertMediaStorage.swift
FileStorage.swift
ImageStorage.swift
LogsStorage.swift
MediaPlayerStorage.swift
PngTuberStorage.swift
RecordingsStorage.swift
ReplaysStorage.swift
ReplayTransitionsStorage.swift
StreamingHistory.swift
VTuberStorage.swift
```

#### `Moblin/Various/Managers/`
```
GeographyManager.swift
GForceManager.swift
Location.swift
WeatherManager.swift
```

#### `Moblin/Various/Network/`
```
DnsLookup.swift
HttpClient.swift
HttpServer.swift
IpMonitor.swift
NetworkInterfaceTypeSelector.swift
NetworkUtils.swift
WebSocketClient.swift
```

#### `Moblin/Various/Subtitles/`
```
Subtitles.swift
TextAligner.swift
Translator.swift
```

#### `Moblin/Various/Utils/`
```
CameraUtils.swift
FileSystemUtils.swift
LocationUtils.swift
UiUtils.swift
Utils.swift
```

#### `Moblin/Various/` — Top-level utilities
```
BluetoothScanner.swift
BondingStatisticsFormatter.swift
CacheAsyncImage.swift
ChatBotCommand.swift
ChatPost.swift
ChatTextToSpeech.swift
Detection.swift
FaxReceiver.swift
Gimbal.swift
KeepSpeakerAlive.swift
Keychain.swift
Log.swift
Media.swift
MediaPlayer.swift
MoblinSettingsUrl.swift
ReplayFrameExtractor.swift
SimpleTimer.swift
SpeechToText.swift
WebBrowserController.swift
```

---

#### `Moblin/Media/` — Media pipeline

##### `HaishinKit/` — Forked/embedded media engine
```
Codec/Audio/
  AudioEncoder.swift
  AudioEncoderRingBuffer.swift
  AudioEncoderSettings.swift
Codec/Video/
  VideoDecoder.swift
  VideoEncoder.swift
  VideoEncoderSettings.swift
  VTSessionProperty.swift
Extension/
  AudioStreamBasicDescription+Extension.swift
  AVCaptureColorSpace+Extension.swift
  AVCaptureDevice.Format+Extension.swift
  AVFrameRateRange+Extension.swift
  Bool+Extension.swift
  Data+Extension.swift
  ExpressibleByIntegerLiteral+Extension.swift
  URL+Extension.swift
  VTCompressionSession+Extension.swift
  VTDecompressionSession+Extension.swift
Flv/
  Flv.swift
Media/Audio/
  AudioMixer.swift
  AudioUnit.swift
  BufferedAudio.swift
Media/
  BufferedStats.swift
  DriftTracker.swift
  MacScreenCapture.swift
  Processor.swift
  Recorder.swift
  TargetLatenciesSynchronizer.swift
Media/Video/
  BufferedVideo.swift
  PreviewView.swift
  VideoEffect.swift
  VideoUnit.swift
Mpeg/
  Adts.swift
  AudioSpecificConfig.swift
  Avc/AvcNalUnit.swift
  Avc/AvcNalUnitPps.swift
  Avc/AvcNalUnitSei.swift
  Avc/AvcNalUnitSps.swift
  Avc/MpegTsVideoConfigAvc.swift
  (+ more MPEG-TS types)
```

##### `AdaptiveBitrate/`
```
AdaptiveBitrateRistExperiment.swift
AdaptiveBitrateSrtBelabox.swift
AdaptiveBitrateSrtFight.swift
```

##### Transport servers/clients
```
RistServer/
RtmpServer/
RtspClient/
Srtla/
Webrtc/
WiFiAware/
```

##### Other
```
Wav.swift
WrappingTimestamp.swift
```

---

#### `Moblin/VideoEffects/` — Video effect processors
```
Alerts/
  AlertsEffect.swift
  AlertsEffectFace.swift
  AlertsEffectMedia.swift
  AlertsEffectVideoReader.swift
AnamorphicLensEffect.swift
BeautyEffect.swift
BingoCardEffect.swift
Blur/
  BlurFilter.swift
  BlurKernel.swift
Browser/
  BrowserEffect.swift
  BrowserEffectServer.swift          # Defines JS API topics + messages
CameraManEffect.swift
ChatEffect.swift
Crt/
  CrtBarrelDistortionFilter.swift
  CrtEffect.swift
Dewarp360/
  Dewarp360Effect.swift
  Dewarp360Filter.swift
DrawOnStreamEffect.swift
EffectUtils.swift
FaceEffect.swift
FixedHorizonEffect.swift
FourThreeEffect.swift
GrayScaleEffect.swift
ImageEffect.swift
LutEffect.swift
MapEffect.swift
MovieEffect.swift
OpacityEffect.swift
PinchEffect.swift
PixellateEffect.swift
PngTuberEffect.swift
PollEffect.swift
QrCodeEffect.swift
RemoveBackgroundEffect.swift
Replay/
  ReplayEffect.swift
  ReplayEffectReplayReader.swift
  ReplayEffectStingerReader.swift
Scoreboard/
  ScoreboardEffect.swift
  ScoreboardEffectGenericView.swift
  ScoreboardEffectGolfFullScorecardView.swift
  ScoreboardEffectGolfView.swift
  ScoreboardEffectModularView.swift
  ScoreboardEffectPadelView.swift
SepiaEffect.swift
ShapeEffect.swift
SlideshowEffect.swift
SnapshotEffect.swift
Text/
  TextEffect.swift
  TextEffectFormatter.swift
  TextFormatStringLoader.swift
TripleEffect.swift
TwinEffect.swift
VideoSourceEffect.swift
VTuberEffect.swift
WheelOfLuckEffect.swift
WhirlpoolEffect.swift
```

---

#### `Moblin/Integrations/`
```
BlackSharkCooler/
  BlackSharkCoolerDevice.swift
CatPrinter/
  AtkinsonDithering.swift
  CatPrinter.swift
  CatPrinterCommands.swift
  CatPrinterCommandsMxw01.swift
  FloydSteinbergDithering.swift
Dji/
  DjiDevice/
    DjiDevice.swift
    DjiDeviceMessage.swift
    DjiDeviceModel.swift
    DjiDeviceScanner.swift
  DjiMessage.swift
Emotes/
  Bttv.swift
  Emotes.swift
  Ffz.swift
  Seventv.swift
GoPro/
  GoPro.swift
OpenAi/
  OpenAi.swift
RealtimeIrl/
  RealtimeIrl.swift
Tesla/
  Protobuf/                          # Generated protobuf files — excluded from lint/format
    car_server.pb.swift
    common.pb.swift
    errors.pb.swift
    keys.pb.swift
    managed_charging.pb.swift
    signatures.pb.swift
    universal_message.pb.swift
    vcsec.pb.swift
    vehicle.pb.swift
  TeslaVehicle.swift
TtsMonster/
  TtsMonster.swift
WorkoutDevice/
  WorkoutDevice.swift
  WorkoutDeviceCyclingPower.swift
  WorkoutDeviceHeartRate.swift
  WorkoutDeviceRunning.swift
```

---

#### `Moblin/RemoteControl/` — Web remote control (Swift side + embedded web assets)
```
(Swift server/client files)
Web/                                   # Built output from WebRemoteControlFrontend — do not edit directly
```

---

#### `Moblin/View/` — SwiftUI views

##### Entry
```
MainView.swift
```

##### `Main/`
```
LockScreenView.swift
MacKeyPressView.swift
SnapshotCountdownView.swift
StealthModeView.swift
```

##### `Stream/` — Live streaming screen
```
StreamView.swift
StreamOverlayView.swift
StreamGridView.swift
CameraLevelView.swift
DrawOnStreamView.swift
Overlay/StreamOverlayChatView.swift
Overlay/StreamOverlayDebugView.swift
Overlay/StreamOverlayLeftView.swift
Overlay/StreamOverlayNavigationView.swift
Overlay/StreamOverlayRightView.swift
Overlay/Right/
  AudioLevelView.swift
  CameraSettingsControlView.swift
  MediaPlayerControlsView.swift
  ReplayView.swift
  SceneSelectorView.swift
  SegmentedPicker.swift
  StreamOverlayRightBeautyView.swift
  StreamOverlayRightFaceView.swift
  StreamOverlayRightPinchView.swift
  StreamOverlayRightPixellateView.swift
  StreamOverlayRightWhirlpoolView.swift
  VideoPreviewView.swift
  ZoomPresetSelctorView.swift
```

##### `ControlBar/`
```
ControlBarLandscapeView.swift
ControlBarPortraitView.swift
ControlBarUtils.swift
BatteryView.swift
StreamButton.swift
ThermalStateSheetView.swift
QuickButtonsView.swift
QuickButton/
  QuickButtonAutoSceneSwitcherView.swift
  QuickButtonBitrateView.swift
  QuickButtonDjiDevicesView.swift
  QuickButtonGoProView.swift
  QuickButtonLiveView.swift
  QuickButtonLutsView.swift
  QuickButtonMacrosView.swift
  QuickButtonMicView.swift
  QuickButtonObsView.swift
  QuickButtonSceneWidgetsView.swift
  QuickButtonStreamSwitcherView.swift
  Chat/
    QuickButtonChatChatterInfoView.swift
    QuickButtonChatModerationView.swift
    QuickButtonChatUrlView.swift
    QuickButtonChatView.swift
RemoteControlAssistant/
  ControlBarRemoteControlAssistantView.swift
```

##### `ExternalDisplay/`
```
ExternalDisplayView.swift
```

##### `Settings/` — Settings navigation tree (deep hierarchy, representative structure)
```
SettingsView.swift                     # Root settings sheet
About/
Audio/
BitratePresets/
BlackSharkCoolers/
Camera/                                # Zoom, stabilization, focus, fixed horizon, controls
CatPrinters/
Chat/                                  # Appearance, layout, TTS, bot, filters, nicknames
Debug/
DeepLinkCreator/
Display/                               # Quick buttons, overlays, network interface names, stream button
DjiDevices/
GameControllers/
Gimbal/
GoPro/
HelpAndSupport/
ImportExport/
Ingests/                               # RIST server, RTMP server, RTSP client, SRTla server, WHEP client, WHIP server
Keyboard/
Location/
Macros/
MediaPlayer/
Moblink/
Recordings/
RemoteControl/
Reset/
Scenes/                                # Scene list, auto-switchers, disconnect protection, widgets
  Widgets/Widget/
    Alerts/                            # Twitch, Kick, ChatBot, sound, image, text, speech-to-text
    BingoCard/
    Browser/
    Chat/
    Crop/
    Effects/                           # LUT, opacity, anamorphic, dewarp360, remove background, shape
    Image/
    Map/
    PngTuber/
    QrCode/
    Scene/
    Scoreboard/                        # Generic, golf, padel, modular, full scorecard
    Slideshow/
    Snapshot/
    Text/
    VideoSource/
    VTuber/
    WheelOfLuck/
SelfieStick/
Store/
StreamingHistory/
Streams/Stream/                        # Per-stream settings
  Audio/
  Chat/
  GoLiveNotification/
  Kick/
  MultiStreaming/
  ObsRemoteControl/
  OpenStreamingPlatform/
  RealtimeIrl/
  Recording/
  Replay/
  Rist/
  Rtmp/
  Snapshot/
  Soop/
  Srt/                                 # Adaptive bitrate, connection priority
  Twitch/
  Url/
  Video/
  Whip/
  Wizard/                              # Platform (Twitch/YouTube/Kick/Soop/OBS) + network setup + custom protocols
```

---

### `Moblin Watch/` — watchOS companion
```
MoblinWatchApp.swift
Shared/
  WatchProtocol.swift                  # iOS ↔ Watch communication protocol
  WatchSettings.swift
Various/
  CacheImage.swift
  ModelScoreboard.swift
  WatchModel.swift
View/
  WatchMainView.swift
  Chat/ChatView.swift
  Control/ControlView.swift
  Preview/PreviewView.swift
  Scoreboard/
    GenericScoreboardView.swift
    PadelScoreboardView.swift
    ScoreboardView.swift
```

---

### `Moblin Widget/`
```
MoblinWidgetApp.swift
```

### `Moblin Live Activity/`
```
MoblinLiveActivityApp.swift
Shared/MoblinLiveActivity.swift
```

### `Moblin Screen Recording/`
```
SampleHandler.swift
Shared/
  SampleBufferCommon.swift
  SampleBufferReceiver.swift
  SampleBufferSender.swift
```

---

### `MoblinTests/` — Test suites
```
AdaptiveBitrateSuite.swift
AmfSuite.swift
AudioMixerSuite.swift
BufferedAudioSuite.swift
ChatBotCommandSuite.swift
HttpClientSuite.swift
LutEffectSuite.swift
Md5Suite.swift
NetworkUtilsSuite.swift
RistSuite.swift
RtmpStreamInfoSuite.swift
RtmpStreamSuite.swift
RtmpSuite.swift
SettingsSuite.swift
SrtSenderSuite.swift
SubtitlesSuite.swift
TextAlignerSuite.swift
TextEffectSuite.swift
TwitchChatSuite.swift
UtilsSuite.swift
ValidateSuite.swift
VideoDimensionsSuite.swift
WavSuite.swift
WrappingTimestampSuite.swift
TestUtils.swift
```

---

### `WebRemoteControlFrontend/` — SolidJS web remote control

Stack: SolidJS + TypeScript + Tailwind CSS v4 + Vite. Built output goes to `Moblin/RemoteControl/Web/` — run `make web-remote-control-frontend-build` after any change.

```
src/
  components.tsx                       # Shared UI components
  config.d.ts
  utils.ts
  index.tsx                            # Main remote control app
  remote.tsx                           # Stream remote control page
  recordings.tsx                       # Recordings browser
  scoreboard.tsx                       # Scoreboard overlay
  golf.tsx                             # Golf scoreboard
  css/
    app.css
    common.css
    golf.css
    recordings.css
    remote.css
    scoreboard.css
index.html
remote.html
recordings.html
scoreboard.html
golf.html
```
