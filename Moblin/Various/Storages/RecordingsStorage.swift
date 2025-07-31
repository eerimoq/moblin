import Foundation
import SwiftUI

private func getRecordingsDirectory() -> URL {
    return createAndGetDirectory(name: "Recordings")
}

class RecordingSettings: Codable {
    var resolution: SettingsStreamResolution
    var fps: Int
    var codec: SettingsStreamCodec
    var recording: SettingsStreamRecording?

    // Fields to be removed at some point. Backwards compatibility.
    // periphery:ignore
    var name: String? = ""
    // periphery:ignore
    var id: UUID? = .init()
    // periphery:ignore
    var enabled: Bool? = false
    // periphery:ignore
    var url: String? = defaultStreamUrl
    // periphery:ignore
    var twitchChannelName: String? = ""
    // periphery:ignore
    var twitchChannelId: String? = ""
    // periphery:ignore
    var kickChatroomId: String? = ""
    // periphery:ignore
    var bitrate: UInt32? = 5_000_000
    // periphery:ignore
    var srt: SettingsStreamSrt? = .init()

    init(settings: SettingsStream) {
        fps = settings.fps
        resolution = settings.resolution
        codec = settings.codec
        recording = settings.recording.clone()
    }

    func resolutionString() -> String {
        return resolution.shortString()
    }

    func codecString() -> String {
        return codec.shortString()
    }

    func audioCodecString() -> String {
        return makeAudioCodecString()
    }
}

private func loadRecordingPath(settings: RecordingSettings) -> URL? {
    guard let recordingPath = settings.recording?.recordingPath else {
        return nil
    }
    var isStale = false
    return try? URL(resolvingBookmarkData: recordingPath, bookmarkDataIsStale: &isStale)
}

class Recording: Identifiable, Codable, ObservableObject {
    var id: UUID = .init()
    let settings: RecordingSettings
    var startTime: Date = .init()
    var stopTime: Date = .init()
    var size: UInt64 = 0
    @Published var description: String = ""
    private var recordingPath: URL?

    init?(settings: SettingsStream) {
        self.settings = RecordingSettings(settings: settings)
        if !isDefaultRecordingPath() {
            recordingPath = loadRecordingPath(settings: self.settings)
            if recordingPath == nil {
                return nil
            }
        }
    }

    enum CodingKeys: CodingKey {
        case id,
             settings,
             startTime,
             stopTime,
             size,
             description
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.settings, settings)
        try container.encode(.startTime, startTime)
        try container.encode(.stopTime, stopTime)
        try container.encode(.size, size)
        try container.encode(.description, description)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        settings = container.decode(.settings, RecordingSettings.self, .init(settings: .init(name: "")))
        startTime = container.decode(.startTime, Date.self, .init())
        stopTime = container.decode(.stopTime, Date.self, .init())
        size = container.decode(.size, UInt64.self, 0)
        description = container.decode(.description, String.self, "")
        recordingPath = loadRecordingPath(settings: settings)
    }

    func subTitle() -> String {
        if !description.isEmpty {
            return description
        } else {
            return "\(settings.resolutionString()), \(settings.fps) FPS, \(size.formatBytes())"
        }
    }

    func name() -> String {
        return "\(id).mp4"
    }

    func length() -> Duration {
        return Duration(
            secondsComponent: Int64(stopTime.timeIntervalSince(startTime)),
            attosecondsComponent: 0
        )
    }

    func currentLength() -> Double {
        // Not perfect as segments are not written that often.
        return Date().timeIntervalSince(startTime)
    }

    func url() -> URL? {
        if isDefaultRecordingPath() {
            return getRecordingsDirectory().appending(component: name())
        } else {
            return recordingPath?.appending(component: name())
        }
    }

    func shareUrl() -> URL? {
        return url()
    }

    func sizeString() -> String {
        return size.formatBytes()
    }

    func getRecordingPath() -> String? {
        if isDefaultRecordingPath() {
            return nil
        } else {
            return recordingPath?.absoluteString ?? String(localized: "No access")
        }
    }

    func isDefaultRecordingPath() -> Bool {
        return settings.recording!.isDefaultRecordingPath()
    }
}

class RecordingsDatabase: Codable, ObservableObject {
    @Published var recordings: [Recording] = []

    init() {}

    enum CodingKeys: CodingKey {
        case recordings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.recordings, recordings)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordings = container.decode(.recordings, [Recording].self, [])
    }

    static func fromString(settings: String) throws -> RecordingsDatabase {
        let database = try JSONDecoder().decode(
            RecordingsDatabase.self,
            from: settings.data(using: .utf8)!
        )
        return database
    }

    func toString() throws -> String {
        return try String.fromUtf8(data: JSONEncoder().encode(self))
    }

    func totalSizeString() -> String {
        return recordings.reduce(0) { total, recording in
            total + recording.size
        }.formatBytes()
    }

    func isFull() -> Bool {
        return recordings.count > 499
    }

    func numberOfRecordingsString() -> String {
        return String(recordings.count)
    }
}

final class RecordingsStorage {
    private var realDatabase = RecordingsDatabase()
    var database: RecordingsDatabase {
        realDatabase
    }

    @AppStorage("recordings") var storage = ""

    func load() {
        do {
            try tryLoadAndMigrate(settings: storage)
        } catch {
            logger.info("recordings: Failed to load with error \(error). Using default.")
            realDatabase = RecordingsDatabase()
        }
        cleanup()
    }

    private func cleanup() {
        database.recordings = database.recordings.filter { recording in
            if recording.isDefaultRecordingPath() {
                if let url = recording.url() {
                    return FileManager.default.fileExists(atPath: url.path())
                } else {
                    return false
                }
            } else {
                return true
            }
        }
        guard let filesAtDefaultLocation = FileManager.default.enumerator(
            at: getRecordingsDirectory(),
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for case let fileUrl as URL in filesAtDefaultLocation
            where !database.recordings.contains(where: { recording in
                if recording.isDefaultRecordingPath() {
                    if let url = recording.url() {
                        return fileUrl.resolvingSymlinksInPath() == url.resolvingSymlinksInPath()
                    } else {
                        return false
                    }
                } else {
                    return true
                }
            })
        {
            logger.debug("recordings: Removing unused file \(fileUrl)")
            fileUrl.remove()
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try RecordingsDatabase.fromString(settings: settings)
        migrateFromOlderVersions()
    }

    func store() {
        do {
            storage = try realDatabase.toString()
        } catch {
            logger.error("recordings: Failed to store.")
        }
    }

    private func migrateFromOlderVersions() {}

    func createRecording(settings: SettingsStream) -> Recording? {
        return Recording(settings: settings)
    }

    func append(recording: Recording) {
        while database.isFull() {
            database.recordings.popLast()?.url()?.remove()
        }
        guard let url = recording.url() else {
            return
        }
        recording.size = url.fileSize
        recording.stopTime = Date()
        database.recordings.insert(recording, at: 0)
    }
}
