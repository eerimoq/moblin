extension Model {
    func startPhotoShoot() {
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
