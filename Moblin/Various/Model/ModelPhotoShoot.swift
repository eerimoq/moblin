extension Model {
    func startPhotoShoot() {
        guard !isChatPhone() else {
            return
        }
        photoShootTimer.startPeriodic(interval: 1) {
            self.media.takePhoto()
        }
    }

    func stopPhotoShoot() {
        photoShootTimer.stop()
    }

    func togglePhotoShoot() {
        if !database.alwaysAttachPhotoShoot {
            reattachCamera()
        }
    }
}
