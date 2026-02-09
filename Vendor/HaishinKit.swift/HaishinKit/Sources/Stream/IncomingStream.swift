@preconcurrency import AVFoundation
import Foundation

/// An actor that provides a stream playback feature.
package final actor IncomingStream {
    public private(set) var isRunning = false
    /// The sound transform value control.
    public var soundTransfrom: SoundTransform? {
        get async {
            return await audioPlayerNode?.soundTransfrom
        }
    }
    private lazy var mediaLink = MediaLink()
    private lazy var audioCodec = AudioCodec()
    private lazy var videoCodec = VideoCodec()
    private weak var stream: (any StreamConvertible)?
    private var audioPlayerNode: AudioPlayerNode?

    /// Creates a new instance.
    public init(_ stream: some StreamConvertible) {
        self.stream = stream
    }

    /// Sets the sound transform value control.
    public func setSoundTransform(_ soundTransfrom: SoundTransform) async {
        await audioPlayerNode?.setSoundTransfrom(soundTransfrom)
    }

    /// Appends a sample buffer for playback.
    public func append(_ buffer: CMSampleBuffer) {
        switch buffer.formatDescription?.mediaType {
        case .audio:
            audioCodec.append(buffer)
        case .video:
            videoCodec.append(buffer)
        default:
            break
        }
    }

    /// Appends an audio buffer for playback.
    public func append(_ buffer: AVAudioBuffer, when: AVAudioTime) {
        audioCodec.append(buffer, when: when)
    }

    /// Attaches an audio player.
    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) async {
        await audioPlayerNode?.detach()
        audioPlayerNode = await audioPlayer?.makePlayerNode()
        await mediaLink.setAudioPlayer(audioPlayerNode)
    }
}

extension IncomingStream: AsyncRunner {
    // MARK: AsyncRunner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        audioCodec.settings.format = .pcm
        videoCodec.startRunning()
        audioCodec.startRunning()
        isRunning = true
        // Deliver decoded video frames directly to the stream without MediaLink pacing.
        // MediaLink uses a display-link choreographer that adds an extra buffering/pacing
        // layer. For recvonly WebRTC streams feeding into an external buffered pipeline
        // (like Moblin's BufferedVideo), this double-pacing causes frame drops and jitter.
        Task {
            for await video in videoCodec.outputStream {
                await stream?.append(video)
            }
        }
        Task {
            await audioPlayerNode?.startRunning()
            for await audio in audioCodec.outputStream {
                await audioPlayerNode?.enqueue(audio.0, when: audio.1)
                await stream?.append(audio.0, when: audio.1)
            }
        }
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        videoCodec.stopRunning()
        audioCodec.stopRunning()
        Task { await audioPlayerNode?.stopRunning() }
        isRunning = false
    }
}
