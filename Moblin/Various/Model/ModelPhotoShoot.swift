extension Model {
    func togglePhotoShoot() {
        photoShootEnabled = !photoShootEnabled
        setQuickButton(type: .photoShoot, isOn: photoShootEnabled)
        stop()
        if database.alwaysAttachPhotoShoot {
            activatePhotoShoot()
        } else {
            attachCamera()
        }
    }

    func setPhotoShootInterval(interval: Int) {
        database.photoShootInterval = interval
        if photoShoot.active {
            start()
        }
    }

    func activatePhotoShoot() {
        guard !isChatPhone(), photoShootEnabled else {
            return
        }
        photoShoot.active = true
        start()
    }

    func handlePhotoTaken() {
        photoShoot.photoTaken = true
        photoShoot.flashTimer.startSingleShot(timeout: 0.15) {
            self.photoShoot.photoTaken = false
        }
        if photoShoot.active {
            start()
        }
    }

    private func start() {
        let interval = Double(database.photoShootInterval)
        photoShoot.nextPhotoTime = ContinuousClock.now + .seconds(interval)
        photoShoot.timer.startSingleShot(timeout: interval) {
            self.media.takePhoto(flash: self.database.photoShootFlash)
        }
    }

    private func stop() {
        photoShoot.timer.stop()
        photoShoot.flashTimer.stop()
        photoShoot.photoTaken = false
        photoShoot.nextPhotoTime = nil
        photoShoot.active = false
    }
}
