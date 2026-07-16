import Combine
import DequeModule
import Foundation
import MusicKit

private enum Action {
    case add(title: String, onCompleted: (String) -> Void)
    case play
    case pause
    case next
    case previous
    case status(onCompleted: (MusicStatus) -> Void)
}

private var songs: [Song] = []
private let player = ApplicationMusicPlayer.shared
private var cancellables = Set<AnyCancellable>()
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
    func setupMusic() {
        player.state.objectWillChange
            .sink {
                let status = player.state.playbackStatus
                logger.info("music: Status \(status)")
            }
            .store(in: &cancellables)
    }

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

    func nextMusic() {
        actions.append(.next)
        tryRunNextAction()
    }

    func previousMusic() {
        actions.append(.previous)
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
        logger.info("music: Running action: \(action)")
        Task {
            do {
                switch action {
                case let .add(title: title, onCompleted: onCompleted):
                    try await addAction(title: title, onCompleted: onCompleted)
                case .play:
                    try await playAction()
                case .pause:
                    pauseAction()
                case .next:
                    try await nextAction()
                case .previous:
                    try await previousAction()
                case let .status(onCompleted: onCompleted):
                    try await statusAction(onCompleted: onCompleted)
                }
            } catch {
                logger.info("music: Error \(error)")
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
            logger.info("music: Adding song \(song)")
            onCompleted("\(song.artistName) - \(song.title) added to the queue.")
            songs.append(song)
            if !player.isPreparedToPlay {
                logger.info("music: Creating queue")
                player.queue = .init(for: [song])
                if playRequested {
                    try await player.play()
                } else {
                    try await player.prepareToPlay()
                }
            } else {
                if playRequested, player.state.playbackStatus == .paused {
                    logger.info("music: New queue")
                    player.queue = .init(for: songs, startingAt: song)
                    try await player.play()
                } else {
                    logger.info("music: Appending to queue")
                    try await player.queue.insert(song, position: .tail)
                }
            }
        } else {
            logger.info("music: Song '\(title)' not found")
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
        try await player.play()
    }

    private func pauseAction() {
        playRequested = false
        player.pause()
    }

    private func nextAction() async throws {
        try await player.skipToNextEntry()
    }

    private func previousAction() async throws {
        try await player.skipToPreviousEntry()
    }

    private func statusAction(onCompleted: (MusicStatus) -> Void) async throws {
        let currentSong = player.queue.currentEntry
        var currentSongIndex: Int?
        var songs: [MusicStatusSong] = []
        for (index, entry) in player.queue.entries.enumerated() {
            if entry.id == currentSong?.id {
                currentSongIndex = index
            }
            songs.append(MusicStatusSong(title: entry.title))
        }
        onCompleted(MusicStatus(playing: player.state.playbackStatus == .playing,
                                currentSongIndex: currentSongIndex,
                                songs: songs))
    }
}
