import AVFoundation
import MetalPetal
import UIKit
import Vision

final class ReplayEffect: VideoEffect {
    private let start: Double
    private let stop: Double
    private var stopPresentationTimeStamp: Double?
    private var playbackCompleted = false

    init(video _: URL, start: Double, stop: Double) {
        self.start = start
        self.stop = stop
    }

    override func getName() -> String {
        return "replay"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let presentationTimeStamp = info.presentationTimeStamp.seconds
        if stopPresentationTimeStamp == nil {
            stopPresentationTimeStamp = presentationTimeStamp + (stop - start)
        }
        playbackCompleted = presentationTimeStamp > stopPresentationTimeStamp!
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = image
        filter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        filter.intensity = 1.0
        return filter.outputImage ?? image
    }

    override func shouldRemove() -> Bool {
        return playbackCompleted
    }
}
