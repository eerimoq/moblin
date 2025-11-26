import Foundation

class DjiDeviceWrapper {
    let device: DjiDevice
    var autoRestartStreamTimer: DispatchSourceTimer?

    init(device: DjiDevice) {
        self.device = device
    }
}

extension Model {
    func startDjiDeviceLiveStream(device: SettingsDjiDevice) {
        if !djiDeviceWrappers.keys.contains(device.id) {
            let djiDevice = DjiDevice()
            djiDevice.delegate = self
            djiDeviceWrappers[device.id] = DjiDeviceWrapper(device: djiDevice)
        }
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        device.isStarted = true
        startDjiDeviceLiveStreamInternal(djiDeviceWrapper: djiDeviceWrapper, device: device)
    }

    private func startDjiDeviceLiveStreamInternal(
        djiDeviceWrapper: DjiDeviceWrapper,
        device: SettingsDjiDevice
    ) {
        var rtmpUrl: String?
        switch device.rtmpUrlType {
        case .server:
            rtmpUrl = device.serverRtmpUrl
        case .custom:
            rtmpUrl = device.customRtmpUrl
        }
        guard let rtmpUrl else {
            return
        }
        guard let deviceId = device.bluetoothPeripheralId else {
            return
        }
        djiDeviceWrapper.device.startLiveStream(
            wifiSsid: device.wifiSsid,
            wifiPassword: device.wifiPassword,
            rtmpUrl: rtmpUrl,
            resolution: device.resolution,
            fps: device.fps,
            bitrate: device.bitrate,
            imageStabilization: device.imageStabilization,
            deviceId: deviceId,
            model: device.model
        )
        startDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper, device: device)
    }

    private func startDjiDeviceTimer(djiDeviceWrapper: DjiDeviceWrapper, device: SettingsDjiDevice) {
        djiDeviceWrapper.autoRestartStreamTimer = DispatchSource
            .makeTimerSource(queue: DispatchQueue.main)
        djiDeviceWrapper.autoRestartStreamTimer!.schedule(deadline: .now() + 45)
        djiDeviceWrapper.autoRestartStreamTimer!.setEventHandler { [weak self] in
            self?
                .makeErrorToast(
                    title: String(localized: "Failed to start live stream from DJI device \(device.name)")
                )
            self?.restartDjiLiveStreamIfNeeded(device: device)
        }
        djiDeviceWrapper.autoRestartStreamTimer!.activate()
    }

    private func stopDjiDeviceTimer(djiDeviceWrapper: DjiDeviceWrapper) {
        djiDeviceWrapper.autoRestartStreamTimer?.cancel()
        djiDeviceWrapper.autoRestartStreamTimer = nil
    }

    func stopDjiDeviceLiveStream(device: SettingsDjiDevice) {
        device.isStarted = false
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        djiDeviceWrapper.device.stopLiveStream()
        stopDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper)
    }

    func restartDjiLiveStreamIfNeededAfterDelay(device: SettingsDjiDevice) {
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        djiDeviceWrapper.autoRestartStreamTimer = DispatchSource
            .makeTimerSource(queue: DispatchQueue.main)
        djiDeviceWrapper.autoRestartStreamTimer!.schedule(deadline: .now() + 5)
        djiDeviceWrapper.autoRestartStreamTimer!.setEventHandler { [weak self] in
            self?.restartDjiLiveStreamIfNeeded(device: device)
        }
        djiDeviceWrapper.autoRestartStreamTimer!.activate()
    }

    private func restartDjiLiveStreamIfNeeded(device: SettingsDjiDevice) {
        switch device.rtmpUrlType {
        case .server:
            guard device.autoRestartStream else {
                stopDjiDeviceLiveStream(device: device)
                return
            }
        case .custom:
            return
        }
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        guard device.isStarted else {
            return
        }
        startDjiDeviceLiveStreamInternal(djiDeviceWrapper: djiDeviceWrapper, device: device)
    }

    func markDjiIsStreamingIfNeeded(rtmpServerStreamId: UUID) {
        for device in database.djiDevices.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId == rtmpServerStreamId else {
                continue
            }
            guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
                continue
            }
            djiDeviceWrapper.autoRestartStreamTimer?.cancel()
            djiDeviceWrapper.autoRestartStreamTimer = nil
        }
    }

    private func getDjiDeviceSettings(djiDevice: DjiDevice) -> SettingsDjiDevice? {
        return database.djiDevices.devices.first(where: { djiDeviceWrappers[$0.id]?.device === djiDevice })
    }

    func setCurrentDjiDevice(device: SettingsDjiDevice) {
        currentDjiDeviceSettings = device
        statusTopRight.djiDeviceStreamingState = getDjiDeviceState(device: device)
    }

    func reloadDjiDevices() {
        for deviceId in djiDeviceWrappers.keys {
            guard let device = database.djiDevices.devices.first(where: { $0.id == deviceId }) else {
                continue
            }
            guard device.isStarted else {
                continue
            }
            guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
                return
            }
            guard djiDeviceWrapper.device.getState() != .streaming else {
                return
            }
            startDjiDeviceLiveStream(device: device)
        }
    }

    func autoStartDjiDevices() {
        for device in database.djiDevices.devices where device.isStarted {
            startDjiDeviceLiveStream(device: device)
        }
    }

    func getDjiDeviceState(device: SettingsDjiDevice) -> DjiDeviceState? {
        return djiDeviceWrappers[device.id]?.device.getState()
    }

    func removeDjiDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = database.djiDevices.devices[offset]
            stopDjiDeviceLiveStream(device: device)
            djiDeviceWrappers.removeValue(forKey: device.id)
        }
        database.djiDevices.devices.remove(atOffsets: offsets)
    }

    func updateDjiDevicesStatus() {
        var statuses: [String] = []
        for device in database.djiDevices.devices {
            guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
                continue
            }
            guard getDjiDeviceState(device: device) == .streaming else {
                continue
            }
            let (status, _) = formatDeviceStatus(
                name: device.name,
                batteryPercentage: djiDeviceWrapper.device.getBatteryPercentage(),
                thermalState: nil
            )
            statuses.append(status)
        }
        let status = statuses.joined(separator: ", ")
        if status != statusTopRight.djiDevicesStatus {
            statusTopRight.djiDevicesStatus = status
        }
    }
}

extension Model: DjiDeviceDelegate {
    func djiDeviceStreamingState(_ device: DjiDevice, state: DjiDeviceState) {
        guard let device = getDjiDeviceSettings(djiDevice: device) else {
            return
        }
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        device.state = state
        if device === currentDjiDeviceSettings {
            statusTopRight.djiDeviceStreamingState = state
        }
        switch state {
        case .connecting:
            startDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper, device: device)
            makeToast(title: String(localized: "Connecting to DJI device \(device.name)"))
        case .streaming:
            if device.rtmpUrlType == .custom {
                stopDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper)
                makeToast(title: String(localized: "DJI device \(device.name) streaming to custom URL"))
            }
        case .wifiSetupFailed:
            makeErrorToast(title: String(localized: "WiFi setup failed for DJI device \(device.name)"),
                           subTitle: String(localized: "Please check the WiFi settings"))
        default:
            break
        }
    }
}
