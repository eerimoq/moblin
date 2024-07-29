import Foundation
import VideoToolbox

// periphery:ignore
private var lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.media")

// periphery:ignore
struct MediaManagerBuffer {
    let sampleBuffer: CMSampleBuffer
    let presentationTimeStamp: Double
    let absolutePresentationTimeStamp: Double?
}

// periphery:ignore
class MediaManagerSource {
    private let name: String
    private var videoBuffers: [MediaManagerBuffer] = []
    private var audioBuffers: [MediaManagerBuffer] = []
    private var jitterBufferDuration: Double
    private var basePresentationTimeStamp: Double?
    private let videoId: Int
    private let audioId: Int

    init(name: String, jitterBufferDuration: Double, videoId: Int, audioId: Int) {
        self.name = name
        self.jitterBufferDuration = jitterBufferDuration
        self.videoId = videoId
        self.audioId = audioId
    }

    // Any FPS.
    func appendVideoFrame(buffer: MediaManagerBuffer) {
        lockQueue.async {
            self.appendVideoFrameInner(buffer: buffer)
        }
    }

    private func appendVideoFrameInner(buffer: MediaManagerBuffer) {
        videoBuffers.append(buffer)
    }

    // PCM at any sample rate and number of channels.
    func appendPcmAudioSamples(buffer: MediaManagerBuffer) {
        lockQueue.async {
            self.appendPcmAudioSamplesInner(buffer: buffer)
        }
    }

    private func appendPcmAudioSamplesInner(buffer: MediaManagerBuffer) {
        audioBuffers.append(buffer)
    }

    func getVideoBuffer(_: Double) {
        if basePresentationTimeStamp == nil {
            basePresentationTimeStamp = videoBuffers.first?.presentationTimeStamp
        }
        guard let basePresentationTimeStamp else {
            return
        }
    }

    func getAudioBuffer(_: Double) {
        if basePresentationTimeStamp == nil {
            basePresentationTimeStamp = audioBuffers.first?.presentationTimeStamp
        }
        guard let basePresentationTimeStamp else {
            return
        }
    }
}

// periphery:ignore
class MediaManager {
    private var presentationTimeStampTick = 0.0
    private var absolutePresentationTimeStamp = 0.0
    private var fps = 30.0
    private var sources: [MediaManagerSource] = []
    private var timer: DispatchSourceTimer?

    deinit {
        stop()
    }

    func start() {
        lockQueue.async {
            self.startInner()
        }
    }

    private func startInner() {
        timer = DispatchSource.makeTimerSource(queue: lockQueue)
        let interval = 1 / fps
        timer!.schedule(deadline: .now() + interval, repeating: interval)
        timer!.setEventHandler { [weak self] in
            self?.handleTimeout()
        }
        timer!.activate()
    }

    func stop() {
        lockQueue.async {
            self.stopInner()
        }
    }

    private func stopInner() {
        timer?.cancel()
        timer = nil
    }

    func addSource(source: MediaManagerSource) {
        lockQueue.async {
            self.addSourceInner(source: source)
        }
    }

    private func addSourceInner(source: MediaManagerSource) {
        sources.append(source)
    }

    func removeSource(source: MediaManagerSource) {
        lockQueue.async {
            self.removeSourceInner(source: source)
        }
    }

    private func removeSourceInner(source: MediaManagerSource) {
        sources.removeAll(where: { $0 === source })
    }

    private func handleTimeout() {
        updatePresentationTimeStamp()
        outputVideo()
        outputAudio()
    }

    private func updatePresentationTimeStamp() {
        presentationTimeStampTick += 1
        absolutePresentationTimeStamp = presentationTimeStampTick / fps
    }

    private func outputVideo() {
        for source in sources {
            source.getVideoBuffer(absolutePresentationTimeStamp)
        }
    }

    private func outputAudio() {
        for source in sources {
            source.getAudioBuffer(absolutePresentationTimeStamp)
        }
    }
}
