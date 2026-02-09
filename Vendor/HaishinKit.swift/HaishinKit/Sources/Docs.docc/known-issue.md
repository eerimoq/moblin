# Known issue

## 🔍 Overview
This section lists known issues that cannot be resolved within HaishinKit. It mainly summarizes problems that occur during development with Xcode.

### When Debugging with Xcode
The following issues may occur while developing with Xcode connected.

#### Application Freezes on Launch
When `MediaMixer#startRunning()` is executed while the app is launched from Xcode, the application may freeze.
It has been confirmed that this does not occur when the application is force-quit and then relaunched.
- iOS18, Xcode16 The issue is still ongoing in the latest version.

#### Freeze When Starting Recording
When `StreamRecorder#startRecording()` is executed while the app is launched from Xcode, the application may freeze.
It has been confirmed that this does not occur when the application is force-quit and then relaunched.
- iOS18, Xcode16 The issue is still ongoing in the latest version.
