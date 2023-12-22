import Foundation

private let recordingsDirectory = URL.documentsDirectory.appending(component: "Recordings")

class Recording: Identifiable {
    var id: UUID = .init()
    var settings: SettingsStream
    var startTime: Date = .init()
    var stopTime: Date = .init()

    init(settings: SettingsStream) {
        self.settings = settings
    }

    func title() -> String {
        return "\(startTime.formatted()), \(length().format())"
    }

    func name() -> String {
        return "\(id).mp4"
    }

    func length() -> Duration {
        return .seconds(999)
    }

    func url() -> URL {
        return recordingsDirectory.appending(component: "\(id)")
    }
}

class RecordingsStorage {
    var recordings: [Recording] = []

    init() {
        do {
            try FileManager.default.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create recordings directory with error \(error.localizedDescription)")
        }
    }

    func createRecording(settings: SettingsStream) -> Recording {
        return Recording(settings: settings)
    }

    func append(recording: Recording) {
        recording.stopTime = Date()
        recordings.append(recording)
    }

    func listRecordings() -> [Recording] {
        return recordings
    }
}
