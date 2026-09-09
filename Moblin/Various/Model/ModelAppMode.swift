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
        case .torch:
            return false
        case .gimbalTracking:
            return false
        case .workout:
            return false
        case .portrait:
            return false
        case .mute:
            return false
        case .mic:
            return false
        case .blackScreen:
            return false
        case .bitrate:
            return false
        case .record:
            return false
        case .image:
            return false
        case .movie:
            return false
        case .grayScale:
            return false
        case .sepia:
            return false
        case .triple:
            return false
        case .twin:
            return false
        case .pixellate:
            return false
        case .stream:
            return false
        case .grid:
            return false
        case .cameraLevel:
            return false
        case .localOverlays:
            return false
        case .draw:
            return false
        case .cameraPreview:
            return false
        case .fourThree:
            return false
        case .crt:
            return false
        case .poll:
            return false
        case .snapshot:
            return false
        case .widgets:
            return false
        case .luts:
            return false
        case .replay:
            return false
        case .connectionPriorities:
            return false
        case .instantReplay:
            return false
        case .pinch:
            return false
        case .whirlpool:
            return false
        case .autoSceneSwitcher:
            return false
        case .blurFaces:
            return false
        case .blurText:
            return false
        case .privacy:
            return false
        case .moblinInMouth:
            return false
        case .glasses:
            return false
        case .sparkle:
            return false
        case .beauty:
            return false
        case .cameraMan:
            return false
        case .videoPreview:
            return false
        case .previewStream:
            return false
        case .photoShoot:
            return false
        default:
            return true
        }
    }

    func appModeChanged() {
        show.chatPhone = isChatPhone()
        mic.current = noMic
        updateQuickButtonPairs()
        updateScreenAutoOff()
        reloadAudioSession()
        reloadStream()
        resetSelectedScene(changeScene: false)
        updateOrientation()
        updateOrientationLock()
        setupAudio()
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
