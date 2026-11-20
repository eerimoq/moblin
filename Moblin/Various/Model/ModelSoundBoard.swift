import Foundation

extension Model {
    func makeAlertSoundUrl(soundId: UUID) -> URL? {
        if let bundledSound = database.alertsMediaGallery.bundledSounds.first(where: { $0.id == soundId }) {
            Bundle.main.url(forResource: "Alerts.bundle/\(bundledSound.name)", withExtension: "mp3")
        } else {
            alertMediaStorage.makePath(id: soundId)
        }
    }

    func playSoundBoardSound(soundId: UUID) {
        soundBoardPlayer?.stop()
        soundBoardPlayer = nil
        guard let url = makeAlertSoundUrl(soundId: soundId) else {
            return
        }
        soundBoardPlayer = try? AudioPlayer(contentsOf: url)
        soundBoardPlayer?.play()
    }
}
