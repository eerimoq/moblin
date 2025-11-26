import SwiftUI

class Tesla: ObservableObject {
    var vehicle: TeslaVehicle?
    var chargeState = CarServer_ChargeState()
    var driveState = CarServer_DriveState()
    var mediaState = CarServer_MediaState()
    @Published var vehicleState: TeslaVehicleState?
    @Published var vehicleVehicleSecurityConnected = false
    @Published var vehicleInfotainmentConnected = false
}

extension Model {
    func reloadTeslaVehicle() {
        stopTeslaVehicle()
        if database.tesla.enabled, database.tesla.vin != "", database.tesla.privateKey != "" {
            tesla.vehicle = TeslaVehicle(vin: database.tesla.vin, privateKeyPem: database.tesla.privateKey)
            tesla.vehicle?.delegate = self
            tesla.vehicle?.start()
        }
    }

    func stopTeslaVehicle() {
        tesla.vehicle?.delegate = nil
        tesla.vehicle?.stop()
        tesla.vehicle = nil
        tesla.vehicleState = nil
        tesla.chargeState = .init()
        tesla.driveState = .init()
        tesla.mediaState = .init()
        tesla.vehicleVehicleSecurityConnected = false
        tesla.vehicleInfotainmentConnected = false
    }

    func teslaAddKeyToVehicle() {
        tesla.vehicle?.addKeyRequestWithRole(privateKeyPem: database.tesla.privateKey)
        makeToast(title: String(localized: "Tap Locks → Add Key in your Tesla and tap your key card"))
    }

    func teslaFlashLights() {
        tesla.vehicle?.flashLights()
    }

    func teslaHonk() {
        tesla.vehicle?.honk()
    }

    func teslaGetChargeState() {
        tesla.vehicle?.getChargeState { state in
            self.tesla.chargeState = state
        }
    }

    func teslaGetDriveState() {
        tesla.vehicle?.getDriveState { state in
            self.tesla.driveState = state
        }
    }

    func teslaGetMediaState() {
        tesla.vehicle?.getMediaState { state in
            self.tesla.mediaState = state
        }
    }

    func teslaOpenTrunk() {
        tesla.vehicle?.openTrunk()
    }

    func teslaCloseTrunk() {
        tesla.vehicle?.closeTrunk()
    }

    func mediaNextTrack() {
        tesla.vehicle?.mediaNextTrack()
    }

    func mediaPreviousTrack() {
        tesla.vehicle?.mediaPreviousTrack()
    }

    func mediaTogglePlayback() {
        tesla.vehicle?.mediaTogglePlayback()
    }

    func textEffectTeslaBatteryLevel() -> String {
        var teslaBatteryLevel = "-"
        if tesla.chargeState.optionalBatteryLevel != nil {
            teslaBatteryLevel = "\(tesla.chargeState.batteryLevel)%"
            if tesla.chargeState.chargerPower != 0 {
                teslaBatteryLevel += " \(tesla.chargeState.chargerPower) kW"
            }
            if tesla.chargeState.optionalMinutesToChargeLimit != nil {
                teslaBatteryLevel += " \(tesla.chargeState.minutesToChargeLimit) minutes left"
            }
        }
        return teslaBatteryLevel
    }

    func textEffectTeslaDrive() -> String {
        var teslaDrive = "-"
        if let shift = tesla.driveState.shiftState.type {
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
                if case let .speed(speed) = tesla.driveState.optionalSpeed {
                    let metersPerSecond = Measurement(value: Double(speed), unit: UnitSpeed.milesPerHour)
                        .converted(to: UnitSpeed.metersPerSecond)
                        .value
                    teslaDrive += " \(format(speed: metersPerSecond))"
                }
                if case let .power(power) = tesla.driveState.optionalPower {
                    teslaDrive += " \(power) kW"
                }
            }
        }
        return teslaDrive
    }

    func textEffectTeslaMedia() -> String {
        var teslaMedia = "-"
        if case let .nowPlayingArtist(artist) = tesla.mediaState.optionalNowPlayingArtist,
           case let .nowPlayingTitle(title) = tesla.mediaState.optionalNowPlayingTitle
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
        tesla.vehicleState = state
    }

    func teslaVehicleVehicleSecurityConnected(_: TeslaVehicle) {
        tesla.vehicleVehicleSecurityConnected = true
    }

    func teslaVehicleInfotainmentConnected(_: TeslaVehicle) {
        tesla.vehicleInfotainmentConnected = true
    }
}
