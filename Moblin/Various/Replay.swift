import AVFoundation
import Collections
import CoreImage
import UIKit

private let replayQueue = DispatchQueue(label: "com.eerimoq.replay", qos: .background)

enum ReplaySpeed {
    case one
    case oneHalf
    case oneFourth
}

protocol ReplayDelegate: AnyObject {
    func replayOutputFrame(image: UIImage, video: URL, offset: Double)
}

private protocol JobDelegate: AnyObject {
    func jobCompleted(image: UIImage?, video: URL, offset: Double)
}

private class Job {
    private let video: URL
    private let offset: Double
    weak var delegate: JobDelegate?
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private let context = CIContext()

    init(video: URL, offset: Double, delegate: JobDelegate) throws {
        self.video = video
        self.offset = offset
        self.delegate = delegate
        try createReader(offset: offset)
    }

    private func createReader(offset: Double) throws {
        let asset = AVAsset(url: video)
        reader = try AVAssetReader(asset: asset)
        let startTime = CMTime(seconds: offset, preferredTimescale: 1)
        let duration = CMTime(seconds: 3, preferredTimescale: 1)
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

class Replay {
    private let url: URL
    private let duration: Double
    private weak var delegate: ReplayDelegate?
    private var job: Job?
    private var pendingOffset: Double?

    init(url: URL, duration: Double, offset: Double, delegate: ReplayDelegate) {
        self.url = url
        self.duration = duration
        self.delegate = delegate
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
        let offsetFromEnd = 30 - pendingOffset
        job = try? Job(video: url, offset: duration - offsetFromEnd, delegate: self)
        self.pendingOffset = nil
    }
}

extension Replay: JobDelegate {
    func jobCompleted(image: UIImage?, video: URL, offset: Double) {
        if let image {
            delegate?.replayOutputFrame(image: image, video: video, offset: offset)
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

    func createFile(completion: @escaping (URL?, Double) -> Void) {
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

    private func createFileInternal(completion: @escaping (URL?, Double) -> Void) {
        guard let initSegment, !dataSegments.isEmpty else {
            return completion(nil, 0)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("replay.mp4")
        do {
            try Data().write(to: url)
            let handle = try FileHandle(forWritingTo: url)
            handle.write(initSegment)
            var duration = 0.0
            for segment in dataSegments {
                handle.write(segment.data)
                duration += segment.duration
            }
            return completion(url, duration)
        } catch {
            logger.info("replay: Error: \(error)")
            return completion(nil, 0)
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
