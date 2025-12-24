import AVFoundation

class KeepSpeakerAlivePlayer {
    static let shared = KeepSpeakerAlivePlayer()
    private var keepSpeakerAlivePlayer: AudioPlayer?
    private var latestPlayTime: Atomic<ContinuousClock.Instant> = .init(.now)

    func audioPlayed() {
        latestPlayTime.mutate { $0 = .now }
    }

    func playIfNeeded(now: ContinuousClock.Instant) {
        guard latestPlayTime.value.duration(to: now) > .seconds(5 * 60) else {
            return
        }
        guard let soundUrl = Bundle.main.url(forResource: "Alerts.bundle/Silence", withExtension: "mp3")
        else {
            return
        }
        keepSpeakerAlivePlayer = try? AudioPlayer(contentsOf: soundUrl)
        keepSpeakerAlivePlayer?.play()
    }
}

class AudioPlayer {
    private let player: AVAudioPlayer

    init(data: Data) throws {
        player = try AVAudioPlayer(data: data)
    }

    init(contentsOf: URL) throws {
        player = try AVAudioPlayer(contentsOf: contentsOf)
    }

    func setDelegate(delegate: AVAudioPlayerDelegate) {
        player.delegate = delegate
    }

    func play() {
        KeepSpeakerAlivePlayer.shared.audioPlayed()
        player.play()
    }

    func stop() {
        player.stop()
    }
}
