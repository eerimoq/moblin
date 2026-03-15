import AVKit
import Foundation

extension Model {
    func setupPictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: streamPreviewView.layer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
        updatePictureInPicture()
    }

    func updatePictureInPicture() {
        if stream.backgroundStreaming, stream.backgroundStreamingPiP, isLive || isRecording {
            if pipController?.contentSource == nil {
                pipController?.contentSource = AVPictureInPictureController.ContentSource(
                    sampleBufferDisplayLayer: streamPreviewView.layer,
                    playbackDelegate: self
                )
            }
        } else {
            pipController?.contentSource = nil
        }
    }

    func pictureInPictureEnabled() -> Bool {
        return pipController?.contentSource != nil
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
