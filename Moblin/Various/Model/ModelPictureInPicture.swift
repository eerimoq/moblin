import AVKit
import Foundation

extension Model {
    func setupPictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        let pipVideoCallVC = AVPictureInPictureVideoCallViewController()
        pipVideoCallVC.preferredContentSize = CGSize(width: 1920, height: 1080)
        pipVideoCallVC.view.addSubview(pipPreviewView)
        pipPreviewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipPreviewView.leadingAnchor.constraint(equalTo: pipVideoCallVC.view.leadingAnchor),
            pipPreviewView.trailingAnchor.constraint(equalTo: pipVideoCallVC.view.trailingAnchor),
            pipPreviewView.topAnchor.constraint(equalTo: pipVideoCallVC.view.topAnchor),
            pipPreviewView.bottomAnchor.constraint(equalTo: pipVideoCallVC.view.bottomAnchor),
        ])
        let pipContentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: streamPreviewView,
            contentViewController: pipVideoCallVC
        )
        let controller = AVPictureInPictureController(contentSource: pipContentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
        pipVideoCallViewController = pipVideoCallVC
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
