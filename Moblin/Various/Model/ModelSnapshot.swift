import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers

struct SnapshotJob {
    let message: String
    let user: String?
    let takeSnapshot: (String) -> Void
}

extension Model {
    func takeSnapshot(isChatBot: Bool = false, message: String? = nil, age: Float = 0.0) {
        guard !isChatPhone() else {
            return
        }
        media.takeSnapshot(age: age) { uiImage, image, portraitImage in
            guard let imageJpeg = uiImage.jpegData(compressionQuality: 0.9) else {
                return
            }
            let uploadToDiscord = !self.stream.discordSnapshotWebhookOnlyWhenLive || self.isLive
            self.saveSnapshotToPhotos(image: uiImage, fallbackImage: imageJpeg)
            self.handleSnapshot(imageJpeg, image, portraitImage, message, isChatBot, uploadToDiscord)
        }
    }

    func takeSnapshotWebRemoteControl(message: String?, age: Float) {
        guard let url = URL(string: database.chat.botCommandSnapshot.webRemoteControlUrl)?
            .appending(path: "snapshot")
            .appending(queryItems: [URLQueryItem(name: "age", value: String(age))])
        else {
            makeErrorToast(title: String(localized: "Invalid chat bot snapshot web remote control URL"))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        httpRequest(request: request, queue: .global()) { data, response, error in
            guard error == nil, response?.http?.isSuccessful == true, let data,
                  let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage,
                  let imageJpeg = uiImage.jpegData(compressionQuality: 0.9)
            else {
                let title = String(localized: "Failed to fetch snapshot from web remote control")
                self.makeErrorToastMain(title: title)
                return
            }
            let image = CIImage(cgImage: cgImage)
            var portraitImage = image
            if image.extent.width > image.extent.height {
                portraitImage = portraitImage.oriented(.left)
            }
            DispatchQueue.main.async {
                self.saveSnapshotToPhotos(image: data)
                self.handleSnapshot(imageJpeg, image, portraitImage, message, true, true)
            }
        }
    }

    func takeSnapshotHeic(age: Float, onComplete: @escaping @MainActor (Data?) -> Void) {
        guard !isChatPhone() else {
            onComplete(nil)
            return
        }
        media.takeSnapshot(age: age) { uiImage, _, _ in
            DispatchQueue.global().async {
                let imageHeic = encodeSnapshotForPhotos(image: uiImage)
                DispatchQueue.main.async {
                    onComplete(imageHeic)
                }
            }
        }
    }

    private func handleSnapshot(_ imageJpeg: Data,
                                _ image: CIImage,
                                _ portraitImage: CIImage,
                                _ message: String?,
                                _ isChatBot: Bool,
                                _ uploadToDiscord: Bool)
    {
        if uploadToDiscord {
            tryUploadSnapshotToDiscord(imageJpeg, message, isChatBot)
        }
        printSnapshotCatPrinters(image: portraitImage)
        appendSnapshotToSnapshotWidgets(image: image)
    }

    private func saveSnapshotToPhotos(image: UIImage, fallbackImage: Data) {
        DispatchQueue.global().async {
            let image = encodeSnapshotForPhotos(image: image) ?? fallbackImage
            DispatchQueue.main.async {
                self.saveSnapshotToPhotos(image: image)
            }
        }
    }

    private func saveSnapshotToPhotos(image: Data) {
        PHPhotoLibrary.shared().performChanges { @Sendable in
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: image, options: nil)
        } completionHandler: { @Sendable _, error in
            if let error {
                self.makeErrorToastMain(title: String(localized: "Failed to save snapshot to Photos"),
                                        subTitle: error.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    self.makeToast(title: String(localized: "Snapshot saved to Photos"))
                }
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
            snapshotJob.takeSnapshot(message)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.snapshot.currentJob = nil
                self.tryTakeNextSnapshot()
            }
        }
    }

    func takeSnapshotWithCountdown(message: String, user: String?, takeSnapshot: @escaping (String) -> Void) {
        snapshotJobs.append(SnapshotJob(message: message, user: user, takeSnapshot: takeSnapshot))
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
        guard let url = getDiscordWebhookUrl(isChatBot) else {
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
    let properties: [String: Any] = [
        kCGImagePropertyIPTCDictionary as String: [
            kCGImagePropertyIPTCKeywords as String: [String(localized: "Moblin snapshot")],
        ],
        kCGImageDestinationLossyCompressionQuality as String: photosImageQuality,
    ]
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    return data as Data
}
