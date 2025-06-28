extension Model {
    func reloadTeslaVehicle() {
        stopTeslaVehicle()
        if database.tesla.enabled!, database.tesla.vin != "", database.tesla.privateKey != "" {
            tesla.teslaVehicle = TeslaVehicle(vin: database.tesla.vin, privateKeyPem: database.tesla.privateKey)
            tesla.teslaVehicle?.delegate = self
            tesla.teslaVehicle?.start()
        }
    }

    func stopTeslaVehicle() {
        tesla.teslaVehicle?.delegate = nil
        tesla.teslaVehicle?.stop()
        tesla.teslaVehicle = nil
        tesla.teslaVehicleState = nil
        tesla.teslaChargeState = .init()
        tesla.teslaDriveState = .init()
        tesla.teslaMediaState = .init()
        tesla.teslaVehicleVehicleSecurityConnected = false
        tesla.teslaVehicleInfotainmentConnected = false
    }

    func teslaAddKeyToVehicle() {
        tesla.teslaVehicle?.addKeyRequestWithRole(privateKeyPem: database.tesla.privateKey)
        makeToast(title: String(localized: "Tap Locks → Add Key in your Tesla and tap your key card"))
    }

    func teslaFlashLights() {
        tesla.teslaVehicle?.flashLights()
    }

    func teslaHonk() {
        tesla.teslaVehicle?.honk()
    }

    func teslaGetChargeState() {
        tesla.teslaVehicle?.getChargeState { state in
            self.tesla.teslaChargeState = state
        }
    }

    func teslaGetDriveState() {
        tesla.teslaVehicle?.getDriveState { state in
            self.tesla.teslaDriveState = state
        }
    }

    func teslaGetMediaState() {
        tesla.teslaVehicle?.getMediaState { state in
            self.tesla.teslaMediaState = state
        }
    }

    func teslaOpenTrunk() {
        tesla.teslaVehicle?.openTrunk()
    }

    func teslaCloseTrunk() {
        tesla.teslaVehicle?.closeTrunk()
    }

    func mediaNextTrack() {
        tesla.teslaVehicle?.mediaNextTrack()
    }

    func mediaPreviousTrack() {
        tesla.teslaVehicle?.mediaPreviousTrack()
    }

    func mediaTogglePlayback() {
        tesla.teslaVehicle?.mediaTogglePlayback()
    }

    func textEffectTeslaBatteryLevel() -> String {
        var teslaBatteryLevel = "-"
        if tesla.teslaChargeState.optionalBatteryLevel != nil {
            teslaBatteryLevel = "\(tesla.teslaChargeState.batteryLevel) %"
            if tesla.teslaChargeState.chargerPower != 0 {
                teslaBatteryLevel += " \(tesla.teslaChargeState.chargerPower) kW"
            }
            if tesla.teslaChargeState.optionalMinutesToChargeLimit != nil {
                teslaBatteryLevel += " \(tesla.teslaChargeState.minutesToChargeLimit) minutes left"
            }
        }
        return teslaBatteryLevel
    }

    func textEffectTeslaDrive() -> String {
        var teslaDrive = "-"
        if let shift = tesla.teslaDriveState.shiftState.type {
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
                if case let .speed(speed) = tesla.teslaDriveState.optionalSpeed {
                    teslaDrive += " \(speed) mph"
                }
                if case let .power(power) = tesla.teslaDriveState.optionalPower {
                    teslaDrive += " \(power) kW"
                }
            }
        }
        return teslaDrive
    }

    func textEffectTeslaMedia() -> String {
        var teslaMedia = "-"
        if case let .nowPlayingArtist(artist) = tesla.teslaMediaState.optionalNowPlayingArtist,
           case let .nowPlayingTitle(title) = tesla.teslaMediaState.optionalNowPlayingTitle
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
        tesla.teslaVehicleState = state
    }

    func teslaVehicleVehicleSecurityConnected(_: TeslaVehicle) {
        tesla.teslaVehicleVehicleSecurityConnected = true
    }

    func teslaVehicleInfotainmentConnected(_: TeslaVehicle) {
        tesla.teslaVehicleInfotainmentConnected = true
    }
}
