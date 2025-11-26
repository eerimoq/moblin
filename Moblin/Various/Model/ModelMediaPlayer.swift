import CoreMedia
import Foundation

class MediaPlayerPlayer: ObservableObject {
    @Published var playing = false
    @Published var position: Float = 0
    @Published var time = "0:00"
    @Published var fileName = "Media name"
    @Published var seeking = false
}

extension Model {
    func initMediaPlayers() {
        for settings in database.mediaPlayers.players {
            addMediaPlayer(settings: settings)
        }
        removeUnusedMediaPlayerFiles()
    }

    private func removeUnusedMediaPlayerFiles() {
        for mediaId in mediaStorage.ids() {
            var found = false
            for player in database.mediaPlayers.players
                where player.playlist.contains(where: { $0.id == mediaId })
            {
                found = true
            }
            if !found {
                mediaStorage.remove(id: mediaId)
            }
        }
    }

    func addMediaPlayer(settings: SettingsMediaPlayer) {
        let mediaPlayer = MediaPlayer(settings: settings, mediaStorage: mediaStorage)
        mediaPlayer.delegate = self
        mediaPlayers[settings.id] = mediaPlayer
        updateMicsListAsync()
    }

    func deleteMediaPlayer(playerId: UUID) {
        mediaPlayers.removeValue(forKey: playerId)
        updateMicsListAsync()
    }

    func updateMediaPlayerSettings(playerId: UUID, settings: SettingsMediaPlayer) {
        mediaPlayers[playerId]?.updateSettings(settings: settings)
    }

    func mediaPlayerTogglePlaying() {
        guard let mediaPlayer = getCurrentMediaPlayer() else {
            return
        }
        if mediaPlayerPlayer.playing {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
        mediaPlayerPlayer.playing = !mediaPlayerPlayer.playing
    }

    func mediaPlayerNext() {
        getCurrentMediaPlayer()?.next()
    }

    func mediaPlayerPrevious() {
        getCurrentMediaPlayer()?.previous()
    }

    func mediaPlayerSeek(position: Double) {
        getCurrentMediaPlayer()?.seek(position: position)
    }

    func mediaPlayerSetSeeking(on: Bool) {
        getCurrentMediaPlayer()?.setSeeking(on: on)
    }

    func getCurrentMediaPlayer() -> MediaPlayer? {
        guard let scene = getSelectedScene() else {
            return nil
        }
        guard scene.videoSource.cameraPosition == .mediaPlayer else {
            return nil
        }
        guard let mediaPlayerSettings = getMediaPlayer(id: scene.videoSource.mediaPlayerCameraId) else {
            return nil
        }
        return mediaPlayers[mediaPlayerSettings.id]
    }

    func deactivateAllMediaPlayers() {
        for mediaPlayer in mediaPlayers.values {
            mediaPlayer.deactivate()
        }
    }

    func playerCameras() -> [(UUID, String)] {
        return database.mediaPlayers.players.map {
            ($0.id, $0.camera())
        }
    }

    func getMediaPlayer(idString: String) -> SettingsMediaPlayer? {
        return database.mediaPlayers.players.first {
            idString == $0.id.uuidString
        }
    }

    func getMediaPlayer(id: UUID) -> SettingsMediaPlayer? {
        return database.mediaPlayers.players.first {
            $0.id == id
        }
    }

    func mediaPlayerCameras() -> [String] {
        return database.mediaPlayers.players.map { $0.camera() }
    }
}

extension Model: MediaPlayerDelegate {
    func mediaPlayerFileLoaded(playerId: UUID, name: String) {
        let name = "Media player: \(name)"
        let latency = mediaPlayerLatency
        media.addBufferedVideo(cameraId: playerId, name: name, latency: latency)
        media.addBufferedAudio(cameraId: playerId, name: name, latency: latency)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //     self.selectMicById(id: "\(playerId) 0")
        // }
    }

    func mediaPlayerFileUnloaded(playerId: UUID) {
        media.removeBufferedVideo(cameraId: playerId)
        media.removeBufferedAudio(cameraId: playerId)
    }

    func mediaPlayerStateUpdate(
        playerId _: UUID,
        name: String,
        playing: Bool,
        position: Double,
        time: String
    ) {
        DispatchQueue.main.async {
            self.mediaPlayerPlayer.playing = playing
            self.mediaPlayerPlayer.fileName = name
            if !self.mediaPlayerPlayer.seeking {
                self.mediaPlayerPlayer.position = Float(position)
            }
            self.mediaPlayerPlayer.time = time
        }
    }

    func mediaPlayerVideoBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: playerId, sampleBuffer: sampleBuffer)
    }

    func mediaPlayerAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: playerId, sampleBuffer: sampleBuffer)
    }
}
