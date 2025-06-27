import CoreImage

extension Model {
    func printAllCatPrinters(image: CIImage, feedPaperDelay: Double? = nil) {
        for catPrinter in catPrinters.values {
            catPrinter.print(image: image, feedPaperDelay: feedPaperDelay)
        }
    }

    func printSnapshotCatPrinters(image: CIImage) {
        for catPrinter in catPrinters.values where
            getCatPrinterSettings(catPrinter: catPrinter)?.printSnapshots == true
        {
            catPrinter.print(image: image, feedPaperDelay: nil)
        }
    }

    func isCatPrinterEnabled(device: SettingsCatPrinter) -> Bool {
        return device.enabled
    }

    func enableCatPrinter(device: SettingsCatPrinter) {
        if !catPrinters.keys.contains(device.id) {
            let catPrinter = CatPrinter()
            catPrinter.delegate = self
            catPrinters[device.id] = catPrinter
        }
        catPrinters[device.id]?.start(
            deviceId: device.bluetoothPeripheralId,
            meowSoundEnabled: device.faxMeowSound
        )
    }

    func catPrinterSetFaxMeowSound(device: SettingsCatPrinter) {
        catPrinters[device.id]?.setMeowSoundEnabled(meowSoundEnabled: device.faxMeowSound)
    }

    func disableCatPrinter(device: SettingsCatPrinter) {
        catPrinters[device.id]?.stop()
    }

    func catPrinterPrintTestImage(device: SettingsCatPrinter) {
        catPrinters[device.id]?.print(image: CIImage.black.cropped(to: .init(
            origin: .zero,
            size: .init(width: 100, height: 10)
        )))
    }

    func getCatPrinterSettings(catPrinter: CatPrinter) -> SettingsCatPrinter? {
        return database.catPrinters.devices.first(where: { catPrinters[$0.id] === catPrinter })
    }

    func setCurrentCatPrinter(device: SettingsCatPrinter) {
        currentCatPrinterSettings = device
        status.catPrinterState = getCatPrinterState(device: device)
    }

    func getCatPrinterState(device: SettingsCatPrinter) -> CatPrinterState {
        return catPrinters[device.id]?.getState() ?? .disconnected
    }

    func autoStartCatPrinters() {
        for device in database.catPrinters.devices where device.enabled {
            enableCatPrinter(device: device)
        }
    }

    func stopCatPrinters() {
        for catPrinter in catPrinters.values {
            catPrinter.stop()
        }
    }

    func isAnyConnectedCatPrinterPrintingChat() -> Bool {
        return catPrinters.values.contains(where: {
            $0.getState() == .connected && getCatPrinterSettings(catPrinter: $0)?.printChat == true
        })
    }

    func isAnyCatPrinterConfigured() -> Bool {
        return database.catPrinters.devices.contains(where: { $0.enabled })
    }

    func areAllCatPrintersConnected() -> Bool {
        return !catPrinters.values.contains(where: {
            getCatPrinterSettings(catPrinter: $0)?.enabled == true && $0.getState() != .connected
        })
    }
}

extension Model: CatPrinterDelegate {
    func catPrinterState(_ catPrinter: CatPrinter, state: CatPrinterState) {
        DispatchQueue.main.async {
            guard let device = self.getCatPrinterSettings(catPrinter: catPrinter) else {
                return
            }
            if device === self.currentCatPrinterSettings {
                self.status.catPrinterState = state
            }
        }
    }
}
