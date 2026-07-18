import Combine
import DequeModule
import Foundation
import MusicKit

private enum Action {
    case add(title: String, onCompleted: (String) -> Void)
    case play
    case pause
    case next(count: Int)
    case previous(count: Int)
    case status(onCompleted: (MusicStatus) -> Void)
}

private var songs: [Song] = []
let musicPlayer = ApplicationMusicPlayer.shared
private var isActionRunning = false
private var actions: Deque<Action> = []
private var playRequested = true

struct MusicStatusSong {
    let title: String
}

struct MusicStatus {
    let playing: Bool
    let currentSongIndex: Int?
    let songs: [MusicStatusSong]
}

extension Model {
    func addMusic(title: String, onCompleted: @escaping (String) -> Void) {
        actions.append(.add(title: title, onCompleted: onCompleted))
        tryRunNextAction()
    }

    func playMusic() {
        actions.append(.play)
        tryRunNextAction()
    }

    func pauseMusic() {
        actions.append(.pause)
        tryRunNextAction()
    }

    func nextMusic(count: Int) {
        actions.append(.next(count: count))
        tryRunNextAction()
    }

    func previousMusic(count: Int) {
        actions.append(.previous(count: count))
        tryRunNextAction()
    }

    func statusMusic(onCompleted: @escaping (MusicStatus) -> Void) {
        actions.append(.status(onCompleted: onCompleted))
        tryRunNextAction()
    }

    private func tryRunNextAction() {
        guard !isActionRunning, let action = actions.popFirst() else {
            return
        }
        isActionRunning = true
        logger.debug("music: Running action: \(action)")
        Task {
            do {
                switch action {
                case let .add(title: title, onCompleted: onCompleted):
                    try await addAction(title: title, onCompleted: onCompleted)
                case .play:
                    try await playAction()
                case .pause:
                    pauseAction()
                case let .next(count: count):
                    try await nextAction(count: count)
                case let .previous(count: count):
                    try await previousAction(count: count)
                case let .status(onCompleted: onCompleted):
                    try await statusAction(onCompleted: onCompleted)
                }
            } catch {
                self.makeErrorToast(title: String(localized: "Music player error"),
                                    subTitle: error.localizedDescription)
            }
            isActionRunning = false
            tryRunNextAction()
        }
    }

    private func addAction(title: String, onCompleted: (String) -> Void) async throws {
        let authStatus = await MusicAuthorization.request()
        guard authStatus == .authorized else {
            logger.info("music: Not authorized")
            return
        }
        if let song = try await findSong(title: title) {
            logger.debug("music: Adding song \(song)")
            onCompleted("\(song.artistName) - \(song.title) added to the queue.")
            songs.append(song)
            if !musicPlayer.isPreparedToPlay {
                logger.debug("music: Creating queue")
                musicPlayer.queue = .init(for: songs)
                if playRequested {
                    try await musicPlayer.play()
                } else {
                    try await musicPlayer.prepareToPlay()
                }
            } else {
                if playRequested, musicPlayer.state.playbackStatus == .paused {
                    logger.debug("music: New queue")
                    musicPlayer.queue = .init(for: songs, startingAt: song)
                    try await musicPlayer.play()
                } else {
                    logger.debug("music: Appending to queue")
                    try await musicPlayer.queue.insert(song, position: .tail)
                }
            }
        } else {
            logger.debug("music: Song '\(title)' not found")
            onCompleted("\(title) not found.")
        }
    }

    private func findSong(title: String) async throws -> Song? {
        if let url = URL(string: title), url.scheme == "https" {
            guard let id = url.dictionaryFromQuery()["i"] else {
                return nil
            }
            let identifier = MusicItemID(rawValue: id)
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: identifier)
            let response = try await request.response()
            return response.items.first
        } else {
            var request = MusicCatalogSearchRequest(term: title, types: [Song.self])
            request.limit = 1
            let response = try await request.response()
            return response.songs.first
        }
    }

    private func playAction() async throws {
        playRequested = true
        try await musicPlayer.play()
    }

    private func pauseAction() {
        playRequested = false
        musicPlayer.pause()
    }

    private func nextAction(count: Int) async throws {
        for _ in 0 ..< min(count, songs.count) {
            try await musicPlayer.skipToNextEntry()
        }
    }

    private func previousAction(count: Int) async throws {
        for _ in 0 ..< min(count, songs.count) {
            try await musicPlayer.skipToPreviousEntry()
        }
    }

    private func statusAction(onCompleted: (MusicStatus) -> Void) async throws {
        let currentSong = musicPlayer.queue.currentEntry
        var currentSongIndex: Int?
        var songs: [MusicStatusSong] = []
        for (index, entry) in musicPlayer.queue.entries.enumerated() {
            if entry.id == currentSong?.id {
                currentSongIndex = index
            }
            songs.append(MusicStatusSong(title: entry.title))
        }
        onCompleted(MusicStatus(playing: musicPlayer.state.playbackStatus == .playing,
                                currentSongIndex: currentSongIndex,
                                songs: songs))
    }
}
