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
        photoShootFlashTimer.stop()
        photoShoot.photoTaken = false
    }

    func setPhotoShootInterval(interval: Int) {
        database.photoShootInterval = interval
        if photoShootEnabled {
            startPhotoShoot()
        }
    }

    func handlePhotoTaken() {
        photoShoot.photoTaken = true
        photoShootFlashTimer.startSingleShot(timeout: 0.15) {
            self.photoShoot.photoTaken = false
        }
    }

    func togglePhotoShoot() {
        if !database.alwaysAttachPhotoShoot {
            attachCamera()
        }
    }
}
