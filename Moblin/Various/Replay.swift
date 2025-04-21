import AVFoundation
import CoreImage
import UIKit

private let replayQueue = DispatchQueue(label: "com.eerimoq.replay")

enum ReplaySpeed {
    case one
    case oneHalf
    case oneFourth
}

protocol ReplayDelegate: AnyObject {
    func replayOutputFrame(image: UIImage)
}

private protocol ReaderDelegate: AnyObject {
    func readerOutputFrame(image: UIImage)
}

private class Reader {
    private let video: URL
    weak var delegate: ReaderDelegate?
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private let context = CIContext()

    init(video: URL, offset: Double, delegate: ReaderDelegate) throws {
        self.video = video
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
            return
        }
        guard let track = tracks?.first else {
            logger.info("replay: No video track in file")
            return
        }
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [String: Any]
        trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        guard let trackOutput else {
            return
        }
        reader?.add(trackOutput)
        reader?.startReading()
        guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
            return
        }
        let ciImage = CIImage(cvPixelBuffer: sampleBuffer.imageBuffer!)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        delegate?.readerOutputFrame(image: UIImage(cgImage: cgImage))
    }
}

class Replay {
    private let recording: Recording
    private let startTime: Double
    private weak var delegate: ReplayDelegate?
    private var reader: Reader?

    init(recording: Recording, offset: Double, delegate: ReplayDelegate) {
        self.recording = recording
        startTime = recording.currentLength() - 30
        self.delegate = delegate
        seekInternal(offset: offset)
    }

    func seek(offset: Double) {
        replayQueue.async { [weak self] in
            self?.seekInternal(offset: offset)
        }
    }

    private func seekInternal(offset: Double) {
        reader?.delegate = nil
        reader = try? Reader(video: recording.url(), offset: startTime + offset, delegate: self)
    }
}

extension Replay: ReaderDelegate {
    func readerOutputFrame(image: UIImage) {
        delegate?.replayOutputFrame(image: image)
    }
}
