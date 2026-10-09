extension Model {
    func startPhotoShoot() {
        guard !isChatPhone() else {
            return
        }
        let interval = Double(database.photoShootInterval)
        photoShoot.interval = interval
        photoShoot.nextPhotoTime = ContinuousClock.now + .seconds(interval)
        photoShoot.running = !photoShootWaitingForCameraAttach
        guard photoShoot.running else {
            return
        }
        photoShootTimer.startPeriodic(interval: interval) {
            self.media.takePhoto(flash: self.database.photoShootFlash)
            self.photoShoot.nextPhotoTime = ContinuousClock.now + .seconds(interval)
        }
    }

    func stopPhotoShoot() {
        photoShootWaitingForCameraAttach = false
        photoShootTimer.stop()
        photoShootFlashTimer.stop()
        photoShoot.photoTaken = false
        photoShoot.running = false
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
        if photoShootEnabled {
            photoShootWaitingForCameraAttach = !database.alwaysAttachPhotoShoot
            startPhotoShoot()
        } else {
            stopPhotoShoot()
        }
        if !database.alwaysAttachPhotoShoot {
            attachCamera()
        }
    }

    func photoShootCameraAttached() {
        guard photoShootWaitingForCameraAttach else {
            return
        }
        photoShootWaitingForCameraAttach = false
        if photoShootEnabled {
            startPhotoShoot()
        }
    }
}
