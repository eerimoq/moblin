import Combine
import DequeModule
import Foundation
@preconcurrency import MusicKit

private enum Action {
    case add(title: String, user: String?, onCompleted: (MusicAddResult) -> Void)
    case play
    case pause
    case next(count: Int)
    case previous(count: Int)
    case status(onCompleted: (MusicStatus) -> Void)
    case clear
    case remove(entryId: String)
    case select(entryId: String)
    case restore
}

private struct MusicEntry {
    let entry: ApplicationMusicPlayer.Queue.Entry
    let songId: MusicItemID
    let title: String
    let artist: String?
    let addedBy: String?

    init(song: Song, addedBy: String?) {
        entry = ApplicationMusicPlayer.Queue.Entry(song)
        songId = song.id
        title = song.title
        artist = song.artistName
        self.addedBy = addedBy
    }
}

private struct StoredMusicEntry: Codable {
    let songId: String
    let title: String
    let artist: String?
    let addedBy: String?
}

@MainActor private var entries: [MusicEntry] = []
@MainActor let musicPlayer = ApplicationMusicPlayer.shared
@MainActor private var isActionRunning = false
@MainActor private var actions: Deque<Action> = []
@MainActor private var playRequested = true
@MainActor private var isRestored = false
private let playlistQueue = DispatchQueue(label: "com.eerimoq.moblin.music-playlist")
private let playlistStorage = SimpleStringStorage(key: "musicPlaylist")

private func loadPlaylist() async -> [StoredMusicEntry] {
    await withCheckedContinuation { continuation in
        playlistQueue.async {
            let data = Data(playlistStorage.get().utf8)
            continuation
                .resume(returning: (try? JSONDecoder().decode([StoredMusicEntry].self, from: data)) ?? [])
        }
    }
}

@MainActor
private func storePlaylist() {
    let playlist = entries.map {
        StoredMusicEntry(songId: $0.songId.rawValue, title: $0.title, artist: $0.artist, addedBy: $0.addedBy)
    }
    playlistQueue.async {
        guard let data = try? JSONEncoder().encode(playlist) else {
            return
        }
        playlistStorage.set(String(bytes: data, encoding: .utf8) ?? "")
    }
}

struct MusicPlaylistSong: Identifiable {
    let id: String
    let title: String
    let artist: String?
    let addedBy: String?
}

@MainActor
func musicCurrentIndex(queue: ApplicationMusicPlayer.Queue) -> Int? {
    guard let currentEntry = queue.currentEntry else {
        return nil
    }
    return queue.entries.map(\.id).firstIndex(of: currentEntry.id)
}

@MainActor
class MusicPlaylist: ObservableObject {
    @Published var songs: [MusicPlaylistSong] = []
    @Published var queue = musicPlayer.queue
}

struct MusicStatusSong {
    let id: String
    let title: String
    let artist: String?
    let addedBy: String?
}

struct MusicStatus {
    let playing: Bool
    let currentSongIndex: Int?
    let songs: [MusicStatusSong]
}

enum MusicAddResult {
    case added(song: String)
    case songNotFound
}

extension Model {
    func addMusic(title: String, user: String?, onCompleted: @escaping (MusicAddResult) -> Void) {
        actions.append(.add(title: title, user: user, onCompleted: onCompleted))
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

    func clearMusic() {
        actions.append(.clear)
        tryRunNextAction()
    }

    func removeMusic(entryId: String) {
        actions.append(.remove(entryId: entryId))
        tryRunNextAction()
    }

    func selectMusic(entryId: String) {
        actions.append(.select(entryId: entryId))
        tryRunNextAction()
    }

    func loadMusic() {
        tryRunNextAction()
    }

    private func setMusicQueue(_ queue: ApplicationMusicPlayer.Queue) {
        musicPlayer.queue = queue
        musicPlaylist.queue = musicPlayer.queue
    }

    private func updateMusicPlaylistSongs() {
        musicPlaylist.songs = entries.map {
            MusicPlaylistSong(id: $0.entry.id, title: $0.title, artist: $0.artist, addedBy: $0.addedBy)
        }
    }

    private func musicEntriesChanged() {
        updateMusicPlaylistSongs()
        storePlaylist()
    }

    private func tryRunNextAction() {
        if !isRestored {
            isRestored = true
            actions.prepend(.restore)
        }
        guard !isActionRunning, let action = actions.popFirst() else {
            return
        }
        isActionRunning = true
        logger.debug("music: Running action: \(action)")
        Task {
            do {
                switch action {
                case let .add(title: title, user: user, onCompleted: onCompleted):
                    try await addAction(title: title, user: user, onCompleted: onCompleted)
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
                case .clear:
                    clearAction()
                case let .remove(entryId: entryId):
                    removeAction(entryId: entryId)
                case let .select(entryId: entryId):
                    try await selectAction(entryId: entryId)
                case .restore:
                    try await restoreAction()
                }
            } catch {
                self.makeErrorToast(title: String(localized: "Music player error"),
                                    subTitle: error.localizedDescription)
            }
            isActionRunning = false
            tryRunNextAction()
        }
    }

    private func addAction(title: String,
                           user: String?,
                           onCompleted: (MusicAddResult) -> Void) async throws
    {
        let title = title.trim()
        let authStatus = await MusicAuthorization.request()
        guard authStatus == .authorized else {
            logger.info("music: Not authorized")
            return
        }
        if let song = try await findSong(title: title) {
            logger.debug("music: Adding song \(song)")
            onCompleted(.added(song: "\(song.artistName) - \(song.title)"))
            let musicEntry = MusicEntry(song: song, addedBy: user)
            let entry = musicEntry.entry
            entries.append(musicEntry)
            musicEntriesChanged()
            if !musicPlayer.isPreparedToPlay || musicPlayer.queue.entries.isEmpty {
                logger.debug("music: Creating queue")
                setMusicQueue(.init(entries.map(\.entry)))
                if playRequested {
                    try await musicPlayer.play()
                } else {
                    try await musicPlayer.prepareToPlay()
                }
            } else {
                if playRequested, musicPlayer.state.playbackStatus == .paused {
                    logger.debug("music: New queue")
                    setMusicQueue(.init(entries.map(\.entry), startingAt: entry))
                    try await musicPlayer.play()
                } else {
                    logger.debug("music: Appending to queue")
                    try await musicPlayer.queue.insert(entry, position: .tail)
                }
            }
        } else {
            logger.debug("music: Song '\(title)' not found")
            onCompleted(.songNotFound)
        }
    }

    private func findSong(title: String) async throws -> Song? {
        guard !title.isEmpty else {
            return nil
        }
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
        for _ in 0 ..< min(count, entries.count) {
            try await musicPlayer.skipToNextEntry()
        }
    }

    private func previousAction(count: Int) async throws {
        for _ in 0 ..< min(count, entries.count) {
            try await musicPlayer.skipToPreviousEntry()
        }
    }

    private func clearAction() {
        playRequested = true
        entries = []
        musicEntriesChanged()
        musicPlayer.stop()
        setMusicQueue(.init(entries.map(\.entry)))
    }

    private func removeAction(entryId: String) {
        guard let index = entries.firstIndex(where: { $0.entry.id == entryId }) else {
            return
        }
        entries.remove(at: index)
        musicEntriesChanged()
        let queueEntryIds = musicPlayer.queue.entries.map(\.id)
        if index < queueEntryIds.count {
            musicPlayer.queue.entries.removeAll { $0.id == queueEntryIds[index] }
        }
    }

    private func selectAction(entryId: String) async throws {
        guard let index = entries.firstIndex(where: { $0.entry.id == entryId }) else {
            return
        }
        playRequested = true
        let queueEntries = Array(musicPlayer.queue.entries)
        if index < queueEntries.count {
            musicPlayer.queue.currentEntry = queueEntries[index]
        } else {
            logger.debug("music: Entry not in queue, creating new queue")
            setMusicQueue(.init(entries.map(\.entry), startingAt: entries[index].entry))
        }
        try await musicPlayer.play()
    }

    private func restoreAction() async throws {
        guard entries.isEmpty else {
            return
        }
        let playlist = await loadPlaylist()
        logger.debug("music: Restoring \(playlist.count) songs")
        guard !playlist.isEmpty else {
            return
        }
        musicPlaylist.songs = playlist.map {
            MusicPlaylistSong(id: UUID().uuidString, title: $0.title, artist: $0.artist, addedBy: $0.addedBy)
        }
        guard MusicAuthorization.currentStatus == .authorized else {
            logger.info("music: Not authorized to restore songs")
            return
        }
        let ids = playlist.map { MusicItemID($0.songId) }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: ids)
        let response = try await request.response()
        for storedEntry in playlist {
            guard let song = response.items.first(where: { $0.id.rawValue == storedEntry.songId }) else {
                continue
            }
            entries.append(MusicEntry(song: song, addedBy: storedEntry.addedBy))
        }
        logger.debug("music: Restored \(entries.count) songs")
        updateMusicPlaylistSongs()
        setMusicQueue(.init(entries.map(\.entry)))
    }

    private func statusAction(onCompleted: (MusicStatus) -> Void) async throws {
        onCompleted(MusicStatus(
            playing: musicPlayer.state.playbackStatus == .playing,
            currentSongIndex: musicCurrentIndex(queue: musicPlayer.queue),
            songs: entries.map {
                MusicStatusSong(id: $0.entry.id, title: $0.title, artist: $0.artist, addedBy: $0.addedBy)
            }
        ))
    }
}
