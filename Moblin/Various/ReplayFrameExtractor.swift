import AVFoundation
import Collections
import CoreImage
import UIKit

private let replayQueue = DispatchQueue(label: "com.eerimoq.replay", qos: .background)

class ReplayBufferFile {
    let url: URL
    let duration: Double
    private let remove: Bool

    init(url: URL, duration: Double, remove: Bool) {
        self.url = url
        self.duration = duration
        self.remove = remove
    }

    deinit {
        if remove {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

protocol ReplayDelegate: AnyObject {
    func replayOutputFrame(image: UIImage, offset: Double, video: ReplayBufferFile, completion: (() -> Void)?)
}

private protocol JobDelegate: AnyObject {
    func jobCompleted(image: UIImage?, video: ReplayBufferFile, offset: Double)
}

private class FrameExtractorJob {
    private let video: ReplayBufferFile
    private let offset: Double
    weak var delegate: JobDelegate?
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private let context = CIContext()

    init(video: ReplayBufferFile, offset: Double, delegate: JobDelegate) throws {
        self.video = video
        self.offset = offset
        self.delegate = delegate
        try createReader(offset: offset)
    }

    private func createReader(offset: Double) throws {
        let asset = AVAsset(url: video.url)
        reader = try AVAssetReader(asset: asset)
        let startTime = CMTime(seconds: offset)
        let duration = CMTime(seconds: 3)
        reader?.timeRange = CMTimeRange(start: startTime, duration: duration)
        asset.loadTracks(withMediaType: .video) { [weak self] tracks, error in
            replayQueue.async {
                self?.loadVideoTrackCompletion(tracks: tracks, error: error)
            }
        }
    }

    private func loadVideoTrackCompletion(tracks: [AVAssetTrack]?, error: (any Error)?) {
        if let error {
            logger.info("replay: Failed to get video track with error: \(error)")
            delegate?.jobCompleted(image: nil, video: video, offset: offset)
            return
        }
        guard let track = tracks?.first else {
            logger.info("replay: No video track in file")
            delegate?.jobCompleted(image: nil, video: video, offset: offset)
            return
        }
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [String: Any]
        trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        guard let trackOutput else {
            delegate?.jobCompleted(image: nil, video: video, offset: offset)
            return
        }
        reader?.add(trackOutput)
        reader?.startReading()
        guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
            delegate?.jobCompleted(image: nil, video: video, offset: offset)
            return
        }
        let ciImage = CIImage(cvPixelBuffer: sampleBuffer.imageBuffer!)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        delegate?.jobCompleted(image: UIImage(cgImage: cgImage), video: video, offset: offset)
    }
}

class ReplayFrameExtractor {
    private let video: ReplayBufferFile
    private weak var delegate: ReplayDelegate?
    private var completion: (() -> Void)?
    private var job: FrameExtractorJob?
    private var pendingOffset: Double?

    init(video: ReplayBufferFile, offset: Double, delegate: ReplayDelegate, completion: (() -> Void)?) {
        self.video = video
        self.delegate = delegate
        self.completion = completion
        seek(offset: offset)
    }

    func seek(offset: Double) {
        replayQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.pendingOffset = offset
            self.tryNextJob()
        }
    }

    private func tryNextJob() {
        guard job == nil, let pendingOffset else {
            return
        }
        job = try? FrameExtractorJob(video: video, offset: pendingOffset, delegate: self)
        self.pendingOffset = nil
    }
}

extension ReplayFrameExtractor: JobDelegate {
    func jobCompleted(image: UIImage?, video: ReplayBufferFile, offset: Double) {
        if let image {
            delegate?.replayOutputFrame(image: image, offset: offset, video: video, completion: completion)
            completion = nil
        }
        job = nil
        tryNextJob()
    }
}

class ReplayBuffer {
    private var initSegment: Data?
    private var dataSegments: Deque<RecorderDataSegment> = []

    func setInitSegment(data: Data) {
        replayQueue.async {
            self.setInitSegmentInternal(data: data)
        }
    }

    func appendDataSegment(segment: RecorderDataSegment) {
        replayQueue.async {
            self.appendDataSegmentInternal(segment: segment)
        }
    }

    func createFile(completion: @escaping (ReplayBufferFile?) -> Void) {
        replayQueue.async {
            self.createFileInternal(completion: completion)
        }
    }

    private func setInitSegmentInternal(data: Data) {
        initSegment = data
        dataSegments.removeAll()
    }

    private func appendDataSegmentInternal(segment: RecorderDataSegment) {
        dataSegments.append(segment)
        while stopTime() - startTime() > 30 {
            dataSegments.removeFirst()
        }
    }

    private func createFileInternal(completion: @escaping (ReplayBufferFile?) -> Void) {
        guard let initSegment, !dataSegments.isEmpty else {
            return completion(nil)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).mp4")
        do {
            try Data().write(to: url)
            let handle = try FileHandle(forWritingTo: url)
            handle.write(initSegment)
            var duration = 0.0
            for segment in dataSegments {
                handle.write(segment.data)
                duration += segment.duration
            }
            return completion(ReplayBufferFile(url: url, duration: duration, remove: true))
        } catch {
            logger.info("replay: Error: \(error)")
            return completion(nil)
        }
    }

    private func startTime() -> Double {
        guard let segment = dataSegments.first else {
            return 0
        }
        return segment.startTime
    }

    private func stopTime() -> Double {
        guard let segment = dataSegments.last else {
            return 0
        }
        return segment.startTime + segment.duration
    }
}
