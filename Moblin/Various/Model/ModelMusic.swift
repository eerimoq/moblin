import Combine
import DequeModule
import Foundation
@preconcurrency import MusicKit

func appleMusicSongId(url: URL) -> String? {
    if url.pathComponents.contains("song") {
        url.lastPathComponent
    } else {
        url.dictionaryFromQuery()["i"]
    }
}

private enum Action {
    case add(title: String, user: String?, requestId: String?, onCompleted: (MusicAddResult) -> Void)
    case find(title: String, onCompleted: (Song?) -> Void)
    case play
    case pause
    case next(count: Int)
    case previous(count: Int)
    case status(onCompleted: (MusicStatus) -> Void)
    case clear
    case remove(entryId: String)
    case select(entryId: String)
    case load
}

private struct MusicEntry: Codable {
    let songId: String
    let title: String
    let artist: String?
    let duration: Int?
    let addedBy: String?
    let requestId: String?
}

enum MusicQueueState {
    case notLoaded
    case empty
    case loaded
}

@MainActor let musicPlayer = ApplicationMusicPlayer.shared
@MainActor private var isActionRunning = false
@MainActor private var actions: Deque<Action> = []
@MainActor private var playRequested = true
private let playlistQueue = DispatchQueue(label: "com.eerimoq.moblin.music-playlist")
private let playlistStorage = SimpleStringStorage(key: "musicPlaylist")

private func loadPlaylist() async -> [MusicEntry] {
    await withCheckedContinuation { continuation in
        playlistQueue.async {
            let data = Data(playlistStorage.get().utf8)
            continuation
                .resume(returning: (try? JSONDecoder().decode([MusicEntry].self, from: data)) ?? [])
        }
    }
}

private func storePlaylist(_ playlist: [MusicEntry]) {
    playlistQueue.async {
        guard let data = try? JSONEncoder().encode(playlist) else {
            return
        }
        playlistStorage.set(String(bytes: data, encoding: .utf8) ?? "")
    }
}

private func makeSong(storedEntry: MusicEntry) -> Song? {
    var attributes: [String: Any] = [
        "name": storedEntry.title,
        "playParams": ["id": storedEntry.songId, "kind": "song"],
    ]
    if let artist = storedEntry.artist {
        attributes["artistName"] = artist
    }
    if let duration = storedEntry.duration {
        attributes["durationInMillis"] = duration * 1000
    }
    let json: [String: Any] = ["id": storedEntry.songId, "type": "songs", "attributes": attributes]
    guard let data = try? JSONSerialization.data(withJSONObject: json) else {
        return nil
    }
    return try? JSONDecoder().decode(Song.self, from: data)
}

func musicDuration(song: Song) -> Int? {
    song.duration.map { Int($0.rounded()) }
}

private func makeMusicEntry(song: Song, addedBy: String?, requestId: String?) -> MusicEntry {
    MusicEntry(songId: song.id.rawValue,
               title: song.title,
               artist: song.artistName,
               duration: musicDuration(song: song),
               addedBy: addedBy,
               requestId: requestId)
}

private func musicSong(entry: ApplicationMusicPlayer.Queue.Entry) -> Song? {
    guard case let .song(song) = entry.item else {
        return nil
    }
    return song
}

struct MusicPlaylistSong: Identifiable {
    let id: String
    let title: String
    let artist: String?
    let duration: Int?
    let addedBy: String?
}

@MainActor
class MusicPlaylist: ObservableObject {
    @Published var queue = musicPlayer.queue
    @Published var state: MusicQueueState = .notLoaded
    fileprivate var entries: [MusicEntry] = []

    func songs() -> [MusicPlaylistSong] {
        guard state == .loaded else {
            return []
        }
        let inSync = queue.entries.count == entries.count
        return queue.entries.enumerated().map { index, queueEntry in
            let song = musicSong(entry: queueEntry)
            return MusicPlaylistSong(id: queueEntry.id,
                                     title: song?.title ?? queueEntry.title,
                                     artist: song?.artistName ?? queueEntry.subtitle,
                                     duration: song.flatMap { musicDuration(song: $0) },
                                     addedBy: inSync ? entries[index].addedBy : nil)
        }
    }

    func currentIndex() -> Int? {
        guard state == .loaded, let currentEntry = queue.currentEntry else {
            return nil
        }
        return queue.entries.map(\.id).firstIndex(of: currentEntry.id)
    }
}

struct MusicStatusSong {
    let id: String
    let title: String
    let artist: String?
    let duration: Int?
    let addedBy: String?
}

struct MusicStatus {
    let playing: Bool
    let currentSongIndex: Int?
    let songs: [MusicStatusSong]
}

enum MusicAddResult {
    case added(song: String)
    case alreadyAdded
    case songNotFound
    case failed
}

extension Model {
    func addMusic(title: String,
                  user: String?,
                  requestId: String? = nil,
                  onCompleted: @escaping (MusicAddResult) -> Void)
    {
        actions.append(.add(title: title, user: user, requestId: requestId, onCompleted: onCompleted))
        tryRunNextAction()
    }

    func makeMusicAddedMessage(song: String, user: String) -> String {
        String(localized: "\(song) added to the queue by \(user).")
    }

    func findMusic(title: String, onCompleted: @escaping (Song?) -> Void) {
        actions.append(.find(title: title, onCompleted: onCompleted))
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
        actions.append(.load)
        tryRunNextAction()
    }

    private func setMusicQueue(_ entries: [ApplicationMusicPlayer.Queue.Entry],
                               startingAt: ApplicationMusicPlayer.Queue.Entry? = nil)
    {
        musicPlayer.queue = .init(entries, startingAt: startingAt)
        musicPlaylist.queue = musicPlayer.queue
        musicPlaylist.state = entries.isEmpty ? .empty : .notLoaded
    }

    private func storeMusicQueue() {
        guard musicPlaylist.state != .notLoaded else {
            return
        }
        if musicPlaylist.state == .empty {
            musicPlaylist.entries = []
        } else if musicPlayer.queue.entries.count != musicPlaylist.entries.count {
            logger.info("music: Queue and playlist out of sync")
        }
        storePlaylist(musicPlaylist.entries)
    }

    private func tryRunNextAction() {
        guard !isActionRunning, let action = actions.popFirst() else {
            return
        }
        isActionRunning = true
        logger.debug("music: Running action: \(action)")
        Task {
            switch action {
            case .find, .clear:
                break
            default:
                do {
                    try await loadQueueIfNeeded()
                } catch {
                    logger.info("music: Load queue failed: \(error)")
                }
            }
            do {
                switch action {
                case let .add(title: title, user: user, requestId: requestId, onCompleted: onCompleted):
                    try await addAction(
                        title: title,
                        user: user,
                        requestId: requestId,
                        onCompleted: onCompleted
                    )
                case let .find(title: title, onCompleted: onCompleted):
                    await findAction(title: title, onCompleted: onCompleted)
                case .play:
                    try await playAction()
                case .pause:
                    await pauseAction()
                case let .next(count: count):
                    try await nextAction(count: count)
                case let .previous(count: count):
                    try await previousAction(count: count)
                case let .status(onCompleted: onCompleted):
                    statusAction(onCompleted: onCompleted)
                case .clear:
                    clearAction()
                case let .remove(entryId: entryId):
                    await removeAction(entryId: entryId)
                case let .select(entryId: entryId):
                    try await selectAction(entryId: entryId)
                case .load:
                    break
                }
            } catch {
                self.makeErrorToast(title: String(localized: "Music player error"),
                                    subTitle: error.localizedDescription)
            }
            isActionRunning = false
            tryRunNextAction()
        }
    }

    private func loadQueueIfNeeded() async throws {
        guard musicPlaylist.state == .notLoaded else {
            return
        }
        let playlist = await loadPlaylist()
        logger.debug("music: Loading \(playlist.count) songs")
        guard !playlist.isEmpty else {
            musicPlaylist.entries = []
            setMusicQueue([])
            return
        }
        guard MusicAuthorization.currentStatus == .authorized else {
            throw "Not authorized"
        }
        var songs = playlist.map { (entry: $0, song: makeSong(storedEntry: $0)) }
        if songs.contains(where: { $0.song == nil }) {
            logger.info("music: Fetching songs from catalog")
            let ids = playlist.map { MusicItemID($0.songId) }
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: ids)
            let response = try await request.response()
            songs = playlist.map { storedEntry in
                (
                    entry: storedEntry,
                    song: response.items.first(where: { $0.id.rawValue == storedEntry.songId })
                )
            }
        }
        let loaded = songs.compactMap { pair in pair.song.map { (entry: pair.entry, song: $0) } }
        musicPlaylist.entries = loaded.map(\.entry)
        setMusicQueue(loaded.map { .init($0.song) })
        try await musicPlayer.prepareToPlay()
        musicPlaylist.state = .loaded
        logger.debug("music: Loaded \(musicPlayer.queue.entries.count) songs")
    }

    private func addAction(title: String,
                           user: String?,
                           requestId: String?,
                           onCompleted: (MusicAddResult) -> Void) async throws
    {
        let title = title.trim()
        let authStatus = await MusicAuthorization.request()
        guard authStatus == .authorized else {
            logger.info("music: Not authorized")
            onCompleted(.failed)
            return
        }
        let song: Song?
        guard musicPlaylist.state != .notLoaded else {
            onCompleted(.failed)
            throw "Playlist not loaded"
        }
        do {
            if let requestId, musicPlaylist.entries.contains(where: { $0.requestId == requestId }) {
                logger.debug("music: Request \(requestId) already added")
                onCompleted(.alreadyAdded)
                return
            }
            song = try await findSong(title: title)
        } catch {
            onCompleted(.failed)
            throw error
        }
        guard let song else {
            logger.debug("music: Song '\(title)' not found")
            onCompleted(.songNotFound)
            return
        }
        logger.debug("music: Adding song \(song)")
        onCompleted(.added(song: "\(song.artistName) - \(song.title)"))
        let musicEntry = makeMusicEntry(song: song, addedBy: user, requestId: requestId)
        let entry = ApplicationMusicPlayer.Queue.Entry(song)
        if musicPlaylist.state != .loaded {
            logger.debug("music: Creating queue")
            setMusicQueue([entry])
            musicPlaylist.entries = [musicEntry]
            if playRequested {
                try await musicPlayer.play()
            } else {
                try await musicPlayer.prepareToPlay()
            }
        } else if playRequested, [.paused, .stopped].contains(musicPlayer.state.playbackStatus) {
            logger.debug("music: New queue")
            let entries = musicPlayer.queue.entries
                .compactMap { musicSong(entry: $0) }
                .map { ApplicationMusicPlayer.Queue.Entry($0) }
            setMusicQueue(entries + [entry], startingAt: entry)
            musicPlaylist.entries.append(musicEntry)
            try await musicPlayer.play()
        } else {
            logger.debug("music: Appending to queue")
            await workaroundAppleMusicTransientQueueEntriesBug()
            try await musicPlayer.queue.insert(entry, position: .tail)
            musicPlaylist.entries.append(musicEntry)
        }
        musicPlaylist.state = .loaded
        storeMusicQueue()
    }

    private func workaroundAppleMusicTransientQueueEntriesBug() async {
        let deadline = ContinuousClock.now + .seconds(5)
        while musicPlayer.queue.entries.contains(where: \.isTransient) {
            guard ContinuousClock.now < deadline else {
                logger.info("music: Queue still has transient entries")
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func findAction(title: String, onCompleted: (Song?) -> Void) async {
        guard await MusicAuthorization.request() == .authorized else {
            onCompleted(nil)
            return
        }
        await onCompleted(try? findSong(title: title.trim()))
    }

    private func findSong(title: String) async throws -> Song? {
        guard !title.isEmpty else {
            return nil
        }
        if let url = URL(string: title), url.scheme == "https" {
            guard let id = appleMusicSongId(url: url) else {
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
        guard musicPlaylist.state == .loaded else {
            return
        }
        try await musicPlayer.play()
        await waitForPlaybackStatus(playing: true)
    }

    private func pauseAction() async {
        playRequested = false
        musicPlayer.pause()
        await waitForPlaybackStatus(playing: false)
    }

    private func waitForPlaybackStatus(playing: Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while (musicPlayer.state.playbackStatus == .playing) != playing, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func nextAction(count: Int) async throws {
        guard musicPlaylist.state == .loaded else {
            return
        }
        for _ in 0 ..< min(count, musicPlayer.queue.entries.count) {
            try await musicPlayer.skipToNextEntry()
        }
    }

    private func previousAction(count: Int) async throws {
        guard musicPlaylist.state == .loaded else {
            return
        }
        for _ in 0 ..< min(count, musicPlayer.queue.entries.count) {
            try await musicPlayer.skipToPreviousEntry()
        }
    }

    private func clearAction() {
        playRequested = true
        musicPlayer.stop()
        musicPlaylist.entries = []
        setMusicQueue([])
        storeMusicQueue()
    }

    private func removeAction(entryId: String) async {
        guard musicPlaylist.state == .loaded else {
            return
        }
        await workaroundAppleMusicTransientQueueEntriesBug()
        if let index = musicPlayer.queue.entries.firstIndex(where: { $0.id == entryId }),
           index < musicPlaylist.entries.count
        {
            musicPlaylist.entries.remove(at: index)
        }
        musicPlayer.queue.entries.removeAll { $0.id == entryId }
        if musicPlayer.queue.entries.isEmpty {
            musicPlayer.stop()
            setMusicQueue([])
        }
        storeMusicQueue()
    }

    private func selectAction(entryId: String) async throws {
        await workaroundAppleMusicTransientQueueEntriesBug()
        guard musicPlaylist.state == .loaded,
              let entry = musicPlayer.queue.entries.first(where: { $0.id == entryId })
        else {
            throw "Entry not found"
        }
        playRequested = true
        musicPlayer.queue.currentEntry = entry
        try await musicPlayer.play()
        await waitForPlaybackStatus(playing: true)
    }

    private func statusAction(onCompleted: (MusicStatus) -> Void) {
        onCompleted(MusicStatus(
            playing: musicPlayer.state.playbackStatus == .playing,
            currentSongIndex: musicPlaylist.currentIndex(),
            songs: musicPlaylist.songs().map {
                MusicStatusSong(id: $0.id,
                                title: $0.title,
                                artist: $0.artist,
                                duration: $0.duration,
                                addedBy: $0.addedBy)
            }
        ))
    }
}
