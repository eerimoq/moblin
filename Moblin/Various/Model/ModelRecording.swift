import AVFoundation
import Foundation

class RecordingProvider: ObservableObject {
    @Published var length = noValue
}

extension Model {
    func startRecording() {
        setIsRecording(value: true)
        var subTitle: String?
        if recordingsStorage.database.isFull() {
            subTitle = String(localized: "Too many recordings. Deleting oldest recording.")
        }
        if resumeRecording() {
            makeToast(title: String(localized: "Recording started"), subTitle: subTitle)
        } else {
            if stream.recording.isDefaultRecordingPath() {
                makeErrorToast(title: String(localized: "Failed to start recording"))
            } else {
                makeErrorToast(title: String(localized: "Failed to start recording"),
                               subTitle: String(localized: "Is the disk connected?"))
            }
            setIsRecording(value: false)
        }
    }

    func stopRecording(showToast: Bool = true, toastTitle: String? = nil, toastSubTitle: String? = nil) {
        guard isRecording else {
            return
        }
        setIsRecording(value: false)
        if showToast {
            makeToast(title: toastTitle ?? String(localized: "Recording stopped"), subTitle: toastSubTitle)
        }
        media.setRecordUrl(url: nil)
        suspendRecording()
    }

    func resumeRecording() -> Bool {
        currentRecording = recordingsStorage.createRecording(settings: stream.clone())
        if currentRecording == nil {
            return false
        }
        media.setRecordUrl(url: currentRecording?.url())
        startRecorderIfNeeded()
        return true
    }

    func suspendRecording() {
        stopRecorderIfNeeded()
        if let currentRecording {
            recordingsStorage.append(recording: currentRecording)
            recordingsStorage.store()
        }
        updateRecordingLength(now: Date())
        currentRecording = nil
    }

    func startRecorderIfNeeded() {
        guard !isRecorderRecording else {
            return
        }
        guard isRecording || stream.replay.enabled else {
            return
        }
        isRecorderRecording = true
        let bitrate = Int(stream.recording.videoBitrate)
        let keyFrameInterval = Int(stream.recording.maxKeyFrameInterval)
        let audioBitrate = Int(stream.recording.audioBitrate)
        media.startRecording(
            url: isRecording ? currentRecording?.url() : nil,
            replay: stream.replay.enabled,
            videoCodec: stream.recording.videoCodec,
            videoBitrate: bitrate != 0 ? bitrate : nil,
            keyFrameInterval: keyFrameInterval != 0 ? keyFrameInterval : nil,
            audioBitrate: audioBitrate != 0 ? audioBitrate : nil
        )
    }

    func stopRecorderIfNeeded(forceStop: Bool = false) {
        guard isRecorderRecording else {
            return
        }
        if forceStop || (!isRecording && !stream.replay.enabled) {
            media.stopRecording()
            isRecorderRecording = false
        }
    }

    func updateRecordingLength(now: Date) {
        if let currentRecording {
            let elapsed = uptimeFormatter.string(from: now.timeIntervalSince(currentRecording.startTime))!
            let size = currentRecording.url()?.fileSize.formatBytes() ?? "-"
            recording.length = "\(elapsed) (\(size))"
            if isWatchLocal() {
                sendRecordingLengthToWatch(recordingLength: recording.length)
            }
        } else if recording.length != noValue {
            recording.length = noValue
            if isWatchLocal() {
                sendRecordingLengthToWatch(recordingLength: recording.length)
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func setIsRecording(value: Bool) {
        isRecording = value
        setGlobalButtonState(type: .record, isOn: value)
        updateQuickButtonStates()
        if isWatchLocal() {
            sendIsRecordingToWatch(isRecording: isRecording)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(recording: isRecording))
    }

    func setCleanRecordings() {
        media.setCleanRecordings(enabled: stream.recording.cleanRecordings)
    }

    func isShowingStatusRecording() -> Bool {
        return isRecording
    }

    private func convertRecordingToMp4(fmp4Url: URL) {
        let start = ContinuousClock.now
        guard let exportSession = AVAssetExportSession(asset: AVURLAsset(url: fmp4Url, options: nil),
                                                       presetName: AVAssetExportPresetPassthrough)
        else {
            return
        }
        let mp4Url = fmp4Url.appendingPathExtension("new")
        mp4Url.remove()
        exportSession.outputURL = mp4Url
        exportSession.outputFileType = .mp4
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .failed:
                break
            case .cancelled:
                break
            case .completed:
                let tempUrl = fmp4Url.appendingPathExtension("old")
                do {
                    try FileManager.default.moveItem(at: fmp4Url, to: tempUrl)
                    try FileManager.default.moveItem(at: mp4Url, to: fmp4Url)
                    tempUrl.remove()
                    logger.info("recorder: Fragmented MP4 converted to MP4 in \(start.duration(to: .now))")
                } catch {
                    logger.info("recorder: Failed to convert fragmented MP4 converted to MP4 with error: \(error)")
                }
            default:
                break
            }
        }
    }
}
