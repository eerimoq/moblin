extension Model {
    func reloadTeslaVehicle() {
        stopTeslaVehicle()
        let tesla = database.tesla
        if tesla.enabled!, tesla.vin != "", tesla.privateKey != "" {
            teslaVehicle = TeslaVehicle(vin: tesla.vin, privateKeyPem: tesla.privateKey)
            teslaVehicle?.delegate = self
            teslaVehicle?.start()
        }
    }

    func stopTeslaVehicle() {
        teslaVehicle?.delegate = nil
        teslaVehicle?.stop()
        teslaVehicle = nil
        teslaVehicleState = nil
        teslaChargeState = .init()
        teslaDriveState = .init()
        teslaMediaState = .init()
        teslaVehicleVehicleSecurityConnected = false
        teslaVehicleInfotainmentConnected = false
    }

    func teslaAddKeyToVehicle() {
        teslaVehicle?.addKeyRequestWithRole(privateKeyPem: database.tesla.privateKey)
        makeToast(title: String(localized: "Tap Locks → Add Key in your Tesla and tap your key card"))
    }

    func teslaFlashLights() {
        teslaVehicle?.flashLights()
    }

    func teslaHonk() {
        teslaVehicle?.honk()
    }

    func teslaGetChargeState() {
        teslaVehicle?.getChargeState { state in
            self.teslaChargeState = state
        }
    }

    func teslaGetDriveState() {
        teslaVehicle?.getDriveState { state in
            self.teslaDriveState = state
        }
    }

    func teslaGetMediaState() {
        teslaVehicle?.getMediaState { state in
            self.teslaMediaState = state
        }
    }

    func teslaOpenTrunk() {
        teslaVehicle?.openTrunk()
    }

    func teslaCloseTrunk() {
        teslaVehicle?.closeTrunk()
    }

    func mediaNextTrack() {
        teslaVehicle?.mediaNextTrack()
    }

    func mediaPreviousTrack() {
        teslaVehicle?.mediaPreviousTrack()
    }

    func mediaTogglePlayback() {
        teslaVehicle?.mediaTogglePlayback()
    }

    func textEffectTeslaBatteryLevel() -> String {
        var teslaBatteryLevel = "-"
        if teslaChargeState.optionalBatteryLevel != nil {
            teslaBatteryLevel = "\(teslaChargeState.batteryLevel) %"
            if teslaChargeState.chargerPower != 0 {
                teslaBatteryLevel += " \(teslaChargeState.chargerPower) kW"
            }
            if teslaChargeState.optionalMinutesToChargeLimit != nil {
                teslaBatteryLevel += " \(teslaChargeState.minutesToChargeLimit) minutes left"
            }
        }
        return teslaBatteryLevel
    }

    func textEffectTeslaDrive() -> String {
        var teslaDrive = "-"
        if let shift = teslaDriveState.shiftState.type {
            switch shift {
            case .invalid:
                teslaDrive = "-"
            case .p:
                teslaDrive = "P"
            case .r:
                teslaDrive = "R"
            case .n:
                teslaDrive = "N"
            case .d:
                teslaDrive = "D"
            case .sna:
                teslaDrive = "SNA"
            }
            if teslaDrive != "P" {
                if case let .speed(speed) = teslaDriveState.optionalSpeed {
                    teslaDrive += " \(speed) mph"
                }
                if case let .power(power) = teslaDriveState.optionalPower {
                    teslaDrive += " \(power) kW"
                }
            }
        }
        return teslaDrive
    }

    func textEffectTeslaMedia() -> String {
        var teslaMedia = "-"
        if case let .nowPlayingArtist(artist) = teslaMediaState.optionalNowPlayingArtist,
           case let .nowPlayingTitle(title) = teslaMediaState.optionalNowPlayingTitle
        {
            if artist.isEmpty {
                teslaMedia = title
            } else {
                teslaMedia = "\(artist) - \(title)"
            }
        }
        return teslaMedia
    }
}

extension Model: TeslaVehicleDelegate {
    func teslaVehicleState(_: TeslaVehicle, state: TeslaVehicleState) {
        switch state {
        case .idle:
            reloadTeslaVehicle()
        case .connected:
            makeToast(title: String(localized: "Connected to your Tesla"))
        default:
            break
        }
        teslaVehicleState = state
    }

    func teslaVehicleVehicleSecurityConnected(_: TeslaVehicle) {
        teslaVehicleVehicleSecurityConnected = true
    }

    func teslaVehicleInfotainmentConnected(_: TeslaVehicle) {
        teslaVehicleInfotainmentConnected = true
    }
}
