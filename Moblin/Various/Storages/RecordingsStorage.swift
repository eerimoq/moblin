import Foundation

private func getRecordingsDirectory() -> URL {
    return createAndGetDirectory(name: "Recordings")
}

private func loadRecordingPath(settings: SettingsStreamRecording?) -> URL? {
    guard let recordingPathBookmark = settings?.recordingPath else {
        return nil
    }
    var isStale = false
    let recordingPath = try? URL(resolvingBookmarkData: recordingPathBookmark, bookmarkDataIsStale: &isStale)
    _ = recordingPath?.startAccessingSecurityScopedResource()
    return recordingPath
}

class Recording {
    private var filename: String
    private var recording: SettingsStreamRecording?
    var startTime: Date = .init()
    private var recordingPath: URL?

    init?(recording: SettingsStreamRecording) {
        self.recording = recording
        var date = Date()
        while true {
            filename = "Recording_\(formatFilenameDateAndTime(date: date)).mp4"
            if url()?.exists() == true {
                date = Date(timeInterval: 1, since: date)
                continue
            }
            break
        }
        if !isDefaultRecordingPath() {
            recordingPath = loadRecordingPath(settings: recording)
            if recordingPath == nil {
                return nil
            }
        }
    }

    private func name() -> String {
        return filename
    }

    func url() -> URL? {
        if isDefaultRecordingPath() {
            return getRecordingsDirectory().appending(component: name())
        } else {
            if recordingPath == nil {
                recordingPath = loadRecordingPath(settings: recording)
            }
            return recordingPath?.appending(component: name())
        }
    }

    private func isDefaultRecordingPath() -> Bool {
        return recording?.isDefaultRecordingPath() ?? true
    }
}

final class RecordingsStorage {
    func createRecording(recording: SettingsStreamRecording) -> Recording? {
        return Recording(recording: recording)
    }

    func defaultStorageDirectory() -> URL {
        return getRecordingsDirectory()
    }
}
