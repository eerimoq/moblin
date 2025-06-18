import SwiftUI

struct SnapshotJob {
    let isChatBot: Bool
    let message: String
    let user: String?
}

extension Model {
    func takeSnapshot(isChatBot: Bool = false, message: String? = nil, noDelay: Bool = false) {
        let age = (isChatBot && !noDelay) ? stream.estimatedViewerDelay : 0.0
        media.takeSnapshot(age: age) { image, portraitImage in
            guard let imageJpeg = image.jpegData(compressionQuality: 0.9) else {
                return
            }
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                self.makeToast(title: String(localized: "Snapshot saved to Photos"))
                self.tryUploadSnapshotToDiscord(imageJpeg, message, isChatBot)
                self.printSnapshotCatPrinters(image: portraitImage)
            }
        }
    }

    private func tryTakeNextSnapshot() {
        guard currentSnapshotJob == nil else {
            return
        }
        currentSnapshotJob = snapshotJobs.popFirst()
        guard currentSnapshotJob != nil else {
            return
        }
        snapshotCountdown = 5
        snapshotCountdownTick()
    }

    func formatSnapshotTakenBy(user: String) -> String {
        return String(localized: "Snapshot taken by \(user).")
    }

    func formatSnapshotTakenSuccessfully(user: String) -> String {
        return String(localized: "\(user), thanks for bringing our photo album to life. 🎉")
    }

    func formatSnapshotTakenNotAllowed(user: String) -> String {
        return String(localized: " \(user), you are not allowed to take snapshots, sorry. 😢")
    }

    private func snapshotCountdownTick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.snapshotCountdown -= 1
            guard self.snapshotCountdown == 0 else {
                self.snapshotCountdownTick()
                return
            }
            guard let snapshotJob = self.currentSnapshotJob else {
                return
            }
            var message = snapshotJob.message
            if let user = snapshotJob.user {
                message += "\n"
                message += self.formatSnapshotTakenBy(user: user)
            }
            self.takeSnapshot(isChatBot: snapshotJob.isChatBot, message: message, noDelay: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.currentSnapshotJob = nil
                self.tryTakeNextSnapshot()
            }
        }
    }

    func takeSnapshotWithCountdown(isChatBot: Bool, message: String, user: String?) {
        snapshotJobs.append(SnapshotJob(isChatBot: isChatBot, message: message, user: user))
        tryTakeNextSnapshot()
    }

    private func getDiscordWebhookUrl(_ isChatBot: Bool) -> URL? {
        if isChatBot {
            return URL(string: stream.discordChatBotSnapshotWebhook)
        } else {
            return URL(string: stream.discordSnapshotWebhook)
        }
    }

    private func tryUploadSnapshotToDiscord(_ image: Data, _ message: String?, _ isChatBot: Bool) {
        guard !stream.discordSnapshotWebhookOnlyWhenLive || isLive, let url = getDiscordWebhookUrl(isChatBot) else {
            return
        }
        logger.debug("Uploading snapshot to Discord of \(image).")
        uploadImage(
            url: url,
            paramName: "snapshot",
            fileName: "snapshot.jpg",
            image: image,
            message: message
        ) { ok in
            DispatchQueue.main.async {
                if ok {
                    self.makeToast(title: String(localized: "Snapshot uploaded to Discord"))
                } else {
                    self.makeErrorToast(title: String(localized: "Failed to upload snapshot to Discord"))
                }
            }
        }
    }

    func setCleanSnapshots() {
        media.setCleanSnapshots(enabled: stream.recording.cleanSnapshots!)
    }
}
