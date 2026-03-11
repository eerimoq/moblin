import AVKit
import Foundation

extension Model {
    func setupPictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        let pipContentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: streamPreviewView.layer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: pipContentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
    }
}

extension Model: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(
        _: AVPictureInPictureController
    ) {}

    func pictureInPictureControllerDidStartPictureInPicture(
        _: AVPictureInPictureController
    ) {}

    func pictureInPictureControllerWillStopPictureInPicture(
        _: AVPictureInPictureController
    ) {}

    func pictureInPictureControllerDidStopPictureInPicture(
        _: AVPictureInPictureController
    ) {}

    func pictureInPictureController(
        _: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        logger.warning("PiP failed to start: \(error)")
    }
}

extension Model: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(
        _: AVPictureInPictureController,
        setPlaying _: Bool
    ) {}

    func pictureInPictureControllerTimeRangeForPlayback(
        _: AVPictureInPictureController
    ) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _: AVPictureInPictureController
    ) -> Bool {
        return false
    }

    func pictureInPictureController(
        _: AVPictureInPictureController,
        didTransitionToRenderSize _: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _: AVPictureInPictureController,
        skipByInterval _: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
