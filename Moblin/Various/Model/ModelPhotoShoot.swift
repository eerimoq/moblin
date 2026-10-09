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
        photoShoot.nextPhotoTime = nil
    }

    func setPhotoShootInterval(interval: Int) {
        database.photoShootInterval = interval
        photoShoot.interval = Double(interval)
        if photoShoot.nextPhotoTime != nil {
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
        stopPhotoShoot()
        photoShoot.interval = Double(database.photoShootInterval)
        if database.alwaysAttachPhotoShoot {
            if photoShootEnabled {
                startPhotoShoot()
            }
        } else {
            attachCamera()
        }
    }

    func photoShootCameraAttached() {
        if photoShootEnabled, photoShoot.nextPhotoTime == nil {
            startPhotoShoot()
        }
    }
}
