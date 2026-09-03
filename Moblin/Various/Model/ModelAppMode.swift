import AVFoundation
import Foundation

extension Model {
    func isChatPhone() -> Bool {
        database.appMode == .chatPhone
    }

    func isQuickButtonAllowed(type: SettingsQuickButtonType) -> Bool {
        guard isChatPhone() else {
            return true
        }
        switch type {
        case .mute, .mic, .bitrate, .record, .recordings, .image, .movie, .grayScale, .sepia, .triple, .twin,
             .pixellate, .stream, .grid, .cameraLevel, .draw, .cameraPreview, .fourThree, .crt, .poll,
             .snapshot, .widgets, .luts, .replay, .connectionPriorities, .instantReplay, .pinch, .whirlpool,
             .autoSceneSwitcher, .blurFaces, .blurText, .privacy, .moblinInMouth, .glasses, .sparkle, .beauty,
             .cameraMan, .videoPreview, .previewStream, .photoShoot:
            return false
        default:
            return true
        }
    }

    func appModeChanged() {
        applyAppMode()
        reloadStream()
        resetSelectedScene(changeScene: false)
        updateOrientation()
        setupAudio()
    }

    func applyAppMode() {
        show.chatPhone = isChatPhone()
        mic.current = noMic
        updateQuickButtonStates()
        updateScreenAutoOff()
        reloadAudioSession()
    }

    func startChatPhoneBackgroundAudio() {
        guard isChatPhone(),
              let url = Bundle.main.url(forResource: "Alerts.bundle/Silence", withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else {
            return
        }
        player.numberOfLoops = -1
        player.play()
        chatPhoneBackgroundAudioPlayer = player
    }

    func stopChatPhoneBackgroundAudio() {
        chatPhoneBackgroundAudioPlayer?.stop()
        chatPhoneBackgroundAudioPlayer = nil
    }
}
