import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers

private func createSnapshotMetadata() -> [String: Any] {
    [
        kCGImagePropertyIPTCDictionary as String: [
            kCGImagePropertyIPTCKeywords as String: [String(localized: "Moblin snapshot")],
        ],
    ]
}

private let snapshotMetadata = createSnapshotMetadata()

struct SnapshotJob {
    let isChatBot: Bool
    let message: String
    let user: String?
}

extension Model {
    func takeSnapshot(isChatBot: Bool = false, message: String? = nil, noDelay: Bool = false) {
        guard !isChatPhone() else {
            return
        }
        let age = (isChatBot && !noDelay) ? stream.estimatedViewerDelay : 0.0
        media.takeSnapshot(age: age) { uiImage, image, portraitImage in
            guard let imageJpeg = uiImage.jpegData(compressionQuality: 0.9) else {
                return
            }
            self.saveSnapshotToPhotos(image: uiImage, fallbackImage: imageJpeg)
            self.makeToast(title: String(localized: "Snapshot saved to Photos"))
            self.tryUploadSnapshotToDiscord(imageJpeg, message, isChatBot)
            self.printSnapshotCatPrinters(image: portraitImage)
            self.appendSnapshotToSnapshotWidgets(image: image)
        }
    }

    private func saveSnapshotToPhotos(image: UIImage, fallbackImage: Data) {
        PHPhotoLibrary.shared().performChanges {
            let image = encodeSnapshotForPhotos(image: image) ?? fallbackImage
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: image, options: nil)
        } completionHandler: { _, error in
            if let error {
                logger.info("snapshot: Error saving snapshot: \(error.localizedDescription)")
            }
        }
    }

    private func appendSnapshotToSnapshotWidgets(image: CIImage) {
        for snapshotEffect in enabledSnapshotEffects {
            snapshotEffect.appendSnapshot(image: image)
        }
    }

    private func tryTakeNextSnapshot() {
        guard snapshot.currentJob == nil else {
            return
        }
        snapshot.currentJob = snapshotJobs.popFirst()
        guard snapshot.currentJob != nil else {
            return
        }
        snapshot.countdown = 5
        snapshotCountdownTick()
    }

    func formatSnapshotTakenBy(user: String) -> String {
        String(localized: "Snapshot taken by \(user).")
    }

    func formatSnapshotTakenSuccessfully(user: String) -> String {
        String(localized: "\(user), thanks for bringing our photo album to life. 🎉")
    }

    func formatSnapshotTakenNotAllowed(user: String) -> String {
        String(localized: " \(user), you are not allowed to take snapshots, sorry. 😢")
    }

    private func snapshotCountdownTick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.snapshot.countdown -= 1
            guard self.snapshot.countdown == 0 else {
                self.snapshotCountdownTick()
                return
            }
            guard let snapshotJob = self.snapshot.currentJob else {
                return
            }
            var message = snapshotJob.message
            if let user = snapshotJob.user {
                message += "\n"
                message += self.formatSnapshotTakenBy(user: user)
            }
            self.takeSnapshot(isChatBot: snapshotJob.isChatBot, message: message, noDelay: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.snapshot.currentJob = nil
                self.tryTakeNextSnapshot()
            }
        }
    }

    func takeSnapshotWithCountdown(isChatBot: Bool, message: String, user: String?) {
        guard !isChatPhone() else {
            return
        }
        snapshotJobs.append(SnapshotJob(isChatBot: isChatBot, message: message, user: user))
        tryTakeNextSnapshot()
    }

    private func getDiscordWebhookUrl(_ isChatBot: Bool) -> URL? {
        if isChatBot {
            URL(string: stream.discordChatBotSnapshotWebhook)
        } else {
            URL(string: stream.discordSnapshotWebhook)
        }
    }

    private func tryUploadSnapshotToDiscord(_ image: Data, _ message: String?, _ isChatBot: Bool) {
        guard !stream.discordSnapshotWebhookOnlyWhenLive || isLive,
              let url = getDiscordWebhookUrl(isChatBot)
        else {
            return
        }
        uploadImage(
            url: url,
            paramName: "snapshot",
            fileName: "snapshot.jpg",
            image: image,
            message: message
        ) { ok in
            if ok {
                self.makeToast(title: String(localized: "Snapshot uploaded to Discord"))
            } else {
                self.makeErrorToast(title: String(localized: "Failed to upload snapshot to Discord"))
            }
        }
    }

    func takeVideoSourcePreviewImage(widget: SettingsWidget,
                                     onComplete: @escaping @MainActor (UIImage?) -> Void)
    {
        guard widget.type == .videoSource,
              let videoSourceId = getVideoSourceId(cameraId: widget.videoSource.toCameraId())
        else {
            onComplete(nil)
            return
        }
        media.takeVideoSourceSnapshot(videoSourceId: videoSourceId, onComplete: onComplete)
    }

    func setCleanSnapshots() {
        media.setCleanSnapshots(enabled: stream.recording.cleanSnapshots)
    }
}

private func encodeSnapshotForPhotos(image: UIImage) -> Data? {
    guard let cgImage = image.cgImage else {
        return nil
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data,
                                                             UTType.heic.identifier as CFString,
                                                             1,
                                                             nil)
    else {
        return nil
    }
    var properties = snapshotMetadata
    properties[kCGImageDestinationLossyCompressionQuality as String] = 1.0
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    return data as Data
}
