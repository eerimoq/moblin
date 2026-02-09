import AVFoundation
import Foundation

/// An object that provides a stream ingest feature.
package final class OutgoingStream {
    package private(set) var isRunning = false

    /// The asynchronous sequence for audio output.
    package var audioOutputStream: AsyncStream<(AVAudioBuffer, AVAudioTime)> {
        return audioCodec.outputStream
    }

    /// Specifies the audio compression properties.
    package var audioSettings: AudioCodecSettings {
        get {
            audioCodec.settings
        }
        set {
            audioCodec.settings = newValue
        }
    }

    /// The audio input format.
    package private(set) var audioInputFormat: CMFormatDescription?

    /// The asynchronous sequence for video output.
    package var videoOutputStream: AsyncStream<CMSampleBuffer> {
        return videoCodec.outputStream
    }

    /// Specifies the video compression properties.
    package var videoSettings: VideoCodecSettings {
        get {
            videoCodec.settings
        }
        set {
            videoCodec.settings = newValue
        }
    }

    /// Specifies the video buffering count.
    package var videoInputBufferCounts = -1

    /// The asynchronous sequence for video input buffer.
    package var videoInputStream: AsyncStream<CMSampleBuffer> {
        if 0 < videoInputBufferCounts {
            return AsyncStream(CMSampleBuffer.self, bufferingPolicy: .bufferingNewest(videoInputBufferCounts)) { continuation in
                self.videoInputContinuation = continuation
            }
        } else {
            return AsyncStream { continuation in
                self.videoInputContinuation = continuation
            }
        }
    }

    /// The video input format.
    package private(set) var videoInputFormat: CMFormatDescription?

    private var audioCodec = AudioCodec()
    private var videoCodec = VideoCodec()
    private var videoInputContinuation: AsyncStream<CMSampleBuffer>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }

    /// Create a new instance.
    package init() {
    }

    /// Appends a sample buffer for publish.
    package func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio:
            audioInputFormat = sampleBuffer.formatDescription
            audioCodec.append(sampleBuffer)
        case .video:
            videoInputFormat = sampleBuffer.formatDescription
            videoInputContinuation?.yield(sampleBuffer)
        default:
            break
        }
    }

    /// Appends a sample buffer for publish.
    package func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        audioInputFormat = audioBuffer.format.formatDescription
        audioCodec.append(audioBuffer, when: when)
    }

    /// Appends a video buffer.
    package func append(video sampleBuffer: CMSampleBuffer) {
        videoCodec.append(sampleBuffer)
    }
}

extension OutgoingStream: Runner {
    // MARK: Runner
    package func startRunning() {
        guard !isRunning else {
            return
        }
        videoCodec.startRunning()
        audioCodec.startRunning()
        isRunning = true
    }

    package func stopRunning() {
        guard isRunning else {
            return
        }
        isRunning = false
        videoCodec.stopRunning()
        audioCodec.stopRunning()
        videoInputContinuation = nil
    }
}
