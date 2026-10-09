extension Model {
    func startPhotoShoot() {
        guard !isChatPhone() else {
            return
        }
        let interval = Double(database.photoShootInterval)
        photoShoot.interval = interval
        photoShoot.nextPhotoTime = ContinuousClock.now + .seconds(interval)
        photoShootTimer.startPeriodic(interval: interval) {
            self.media.takePhoto(flash: self.database.photoShootFlash)
            self.photoShoot.nextPhotoTime = ContinuousClock.now + .seconds(interval)
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
