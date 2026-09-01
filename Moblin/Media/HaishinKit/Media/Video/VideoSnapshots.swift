import AVFoundation
import Collections
import CoreImage
import UIKit
@preconcurrency import Vision

final class VideoSnapshots {
    private let context: CIContext
    private var cleanSnapshots = false
    private var takeSnapshotAge: Float = 0.0
    private var takeSnapshotComplete: (@MainActor (UIImage, CIImage, CIImage) -> Void)?
    private var takeSnapshotSampleBuffers: Deque<CMSampleBuffer> = []

    init(context: CIContext) {
        self.context = context
    }

    func setCleanSnapshots(enabled: Bool) {
        cleanSnapshots = enabled
    }

    func takeSnapshot(age: Float, onComplete: @escaping @MainActor (UIImage, CIImage, CIImage) -> Void) {
        takeSnapshotAge = age
        takeSnapshotComplete = onComplete
    }

    func takeVideoSourceSnapshot(_ imageBuffer: CVImageBuffer,
                                 _ onComplete: @escaping @MainActor (UIImage?) -> Void)
    {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            DispatchQueue.main.async { onComplete(nil) }
            return
        }
        let uiImage = UIImage(cgImage: cgImage)
        DispatchQueue.main.async { onComplete(uiImage) }
    }

    func handleTakeSnapshot(_ cleanSampleBuffer: CMSampleBuffer,
                            _ modSampleBuffer: CMSampleBuffer,
                            _ presentationTimeStamp: Double,
                            _ makeCopy: (CMSampleBuffer) -> CMSampleBuffer?)
    {
        let sampleBuffer = cleanSnapshots ? cleanSampleBuffer : modSampleBuffer
        let latestPresentationTimeStamp = takeSnapshotSampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
        if presentationTimeStamp > latestPresentationTimeStamp + 3.0 {
            guard let sampleBuffer = makeCopy(sampleBuffer) else {
                return
            }
            takeSnapshotSampleBuffers.append(sampleBuffer)
            if takeSnapshotSampleBuffers.count > 3 {
                takeSnapshotSampleBuffers.removeFirst()
            }
        }
        guard let takeSnapshotComplete else {
            return
        }
        guard let sampleBuffer = makeCopy(sampleBuffer) else {
            return
        }
        DispatchQueue.global().async {
            self.takeSnapshot(
                sampleBuffer,
                self.takeSnapshotSampleBuffers,
                presentationTimeStamp,
                self.takeSnapshotAge,
                takeSnapshotComplete
            )
        }
        self.takeSnapshotComplete = nil
    }

    private func findBestSnapshot(_ sampleBuffer: CMSampleBuffer,
                                  _ sampleBuffers: Deque<CMSampleBuffer>,
                                  _ presentationTimeStamp: Double,
                                  _ age: Float,
                                  _ onCompleted: @escaping @MainActor (CVImageBuffer?) -> Void)
    {
        if age == 0.0 {
            DispatchQueue.main.async {
                onCompleted(sampleBuffer.imageBuffer)
            }
        } else {
            let requestedPresentationTimeStamp = presentationTimeStamp - Double(age)
            let sampleBufferAtAge = sampleBuffers.last(where: {
                $0.presentationTimeStamp.seconds <= requestedPresentationTimeStamp
            }) ?? sampleBuffers.first ?? sampleBuffer
            if #available(iOS 18, *) {
                var sampleBuffers = sampleBuffers
                sampleBuffers.append(sampleBuffer)
                findBestSnapshotUsingAesthetics(sampleBufferAtAge, sampleBuffers, onCompleted)
            } else {
                DispatchQueue.main.async {
                    onCompleted(sampleBufferAtAge.imageBuffer)
                }
            }
        }
    }

    @available(iOS 18, *)
    private func findBestSnapshotUsingAesthetics(_ preferredSampleBuffer: CMSampleBuffer,
                                                 _ sampleBuffers: Deque<CMSampleBuffer>,
                                                 _ onComplete: @escaping @MainActor (CVImageBuffer?) -> Void)
    {
        Task {
            var bestSampleBuffer = preferredSampleBuffer
            var bestResult = try? await CalculateImageAestheticsScoresRequest()
                .perform(on: preferredSampleBuffer)
            for sampleBuffer in sampleBuffers {
                guard let result = try? await CalculateImageAestheticsScoresRequest()
                    .perform(on: sampleBuffer)
                else {
                    continue
                }
                if bestResult == nil || result.overallScore > bestResult!.overallScore + 0.2 {
                    bestSampleBuffer = sampleBuffer
                    bestResult = result
                }
            }
            DispatchQueue.main.async {
                onComplete(bestSampleBuffer.imageBuffer)
            }
        }
    }

    private func takeSnapshot(_ sampleBuffer: CMSampleBuffer,
                              _ sampleBuffers: Deque<CMSampleBuffer>,
                              _ presentationTimeStamp: Double,
                              _ age: Float,
                              _ onComplete: @escaping @MainActor (UIImage, CIImage, CIImage) -> Void)
    {
        findBestSnapshot(sampleBuffer, sampleBuffers, presentationTimeStamp, age) { @MainActor imageBuffer in
            guard let imageBuffer else {
                return
            }
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent)!
            let image = UIImage(cgImage: cgImage)
            var portraitImage = ciImage
            if !imageBuffer.isPortrait() {
                portraitImage = portraitImage.oriented(.left)
            }
            onComplete(image, ciImage, portraitImage)
        }
    }
}
