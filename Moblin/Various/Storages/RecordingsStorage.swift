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
    var id: UUID = .init()
    var recording: SettingsStreamRecording?
    var startTime: Date = .init()
    private var recordingPath: URL?

    init?(recording: SettingsStreamRecording) {
        self.recording = recording
        if !isDefaultRecordingPath() {
            recordingPath = loadRecordingPath(settings: recording)
            if recordingPath == nil {
                return nil
            }
        }
    }

    func name() -> String {
        return "\(id).mp4"
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

    func isDefaultRecordingPath() -> Bool {
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
