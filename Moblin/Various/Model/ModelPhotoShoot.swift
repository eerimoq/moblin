extension Model {
    func startPhotoShoot() {
        guard !isChatPhone() else {
            return
        }
        photoShootTimer.startPeriodic(interval: Double(database.photoShootInterval)) {
            self.media.takePhoto(flash: self.database.photoShootFlash)
        }
    }

    func stopPhotoShoot() {
        photoShootTimer.stop()
    }

    func setPhotoShootInterval(interval: Int) {
        database.photoShootInterval = interval
        if photoShootEnabled {
            startPhotoShoot()
        }
    }

    func togglePhotoShoot() {
        if !database.alwaysAttachPhotoShoot {
            attachCamera()
        }
    }
}
