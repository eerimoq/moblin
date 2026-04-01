import Foundation

extension Model {
    func ingestVideoSources() -> [(UUID, String)] {
        var sources: [(UUID, String)] = []
        sources += rtmpCameras()
        sources += srtlaCameras()
        sources += ristCameras()
        sources += rtspCameras()
        sources += whipCameras()
        return sources
    }

    func ingestAudioSources() -> [(UUID, String)] {
        return ingestVideoSources()
    }

    func talkBackVideoSourceName() -> String {
        let id = database.talkBack.videoSourceId
        return ingestVideoSources().first(where: { $0.0 == id })?.1 ?? noneCamera
    }

    func talkBackAudioSourceName() -> String {
        let id = database.talkBack.audioSourceId
        return ingestAudioSources().first(where: { $0.0 == id })?.1 ?? noneCamera
    }

    func setTalkBackVideoSourceId(_ id: UUID) {
        database.talkBack.videoSourceId = id
    }

    func setTalkBackAudioSourceId(_ id: UUID) {
        database.talkBack.audioSourceId = id
        updateTalkBackAudio()
    }

    func updateTalkBackAudio() {
        let sources = ingestAudioSources()
        let id = database.talkBack.audioSourceId
        if sources.contains(where: { $0.0 == id }) {
            media.setTalkBackAudioId(id)
        } else {
            media.setTalkBackAudioId(nil)
        }
    }

    func toggleTalkBackVideo() {
        showTalkBackVideo.toggle()
    }
}
