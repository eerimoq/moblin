extension Model {
    func startPhotoShoot() {
        guard !isChatPhone() else {
            return
        }
        let interval = Double(database.photoShootInterval)
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

    func setPhotoShootEnabled(enabled: Bool) {
        photoShootEnabled = enabled
        setQuickButton(type: .photoShoot, isOn: enabled)
        stopPhotoShoot()
        if database.alwaysAttachPhotoShoot {
            activatePhotoShoot()
        } else {
            attachCamera()
        }
    }

    func togglePhotoShoot() {
        setPhotoShootEnabled(enabled: !photoShootEnabled)
    }

    func activatePhotoShoot() {
        if photoShootEnabled, photoShoot.nextPhotoTime == nil {
            startPhotoShoot()
        }
    }
}
