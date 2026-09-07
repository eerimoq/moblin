import Foundation

extension Model {
    func startDjiDeviceLiveStream(device: SettingsDjiDevice) {
        if !djiDevices.keys.contains(device.id) {
            let djiDevice = DjiDevice()
            djiDevice.delegate = self
            djiDevices[device.id] = djiDevice
        }
        guard let djiDevice = djiDevices[device.id] else {
            return
        }
        device.isStarted = true
        startDjiDeviceLiveStreamInternal(djiDevice: djiDevice, device: device)
    }

    func stopDjiDeviceLiveStream(device: SettingsDjiDevice) {
        device.isStarted = false
        device.autoRestartStreamTimer.stop()
        djiDevices[device.id]?.stopLiveStream()
    }

    func restartDjiLiveStreamIfNeededAfterDelay(device: SettingsDjiDevice) {
        startDjiDeviceRestartTimer(device: device, timeout: 5)
    }

    func markDjiIsStreamingIfNeeded(rtmpServerStreamId: UUID) {
        for device in database.djiDevices.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId == rtmpServerStreamId else {
                continue
            }
            device.autoRestartStreamTimer.stop()
        }
    }

    func setCurrentDjiDevice(device: SettingsDjiDevice) {
        currentDjiDeviceSettings = device
        statusTopRight.djiDeviceStreamingState = djiDevices[device.id]?.getState()
    }

    func reloadDjiDevices() {
        for deviceId in djiDevices.keys {
            guard let device = database.djiDevices.devices.first(where: { $0.id == deviceId }) else {
                continue
            }
            guard device.isStarted else {
                continue
            }
            guard let djiDevice = djiDevices[device.id] else {
                continue
            }
            guard djiDevice.getState() != .streaming else {
                continue
            }
            startDjiDeviceLiveStream(device: device)
        }
    }

    func reloadDjiDevices(enabledDeviceIds: Set<UUID>) {
        for device in database.djiDevices.devices {
            if enabledDeviceIds.contains(device.id) {
                if !device.isStarted {
                    startDjiDeviceLiveStream(device: device)
                }
            } else {
                stopDjiDeviceLiveStream(device: device)
            }
        }
    }

    func reloadDjiDevicesAfterSettingsImport() {
        for (deviceId, djiDevice) in djiDevices
            where !database.djiDevices.devices.contains(where: { $0.id == deviceId })
        {
            djiDevice.stopLiveStream()
            djiDevices.removeValue(forKey: deviceId)
        }
        autoStartDjiDevices()
    }

    func autoStartDjiDevices() {
        for device in database.djiDevices.devices where device.isStarted {
            startDjiDeviceLiveStream(device: device)
        }
    }

    func removeDjiDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = database.djiDevices.devices[offset]
            stopDjiDeviceLiveStream(device: device)
            djiDevices.removeValue(forKey: device.id)
        }
        database.djiDevices.devices.remove(atOffsets: offsets)
    }

    func updateDjiDevicesStatus() {
        var statuses: [String] = []
        for device in database.djiDevices.devices {
            guard let djiDevice = djiDevices[device.id] else {
                continue
            }
            guard djiDevice.getState() == .streaming else {
                continue
            }
            let (status, ok) = formatDeviceStatus(
                name: device.name,
                batteryPercentage: djiDevice.getBatteryPercentage(),
                thermalState: nil
            )
            statuses.append(status)
            if !ok, database.chat.botEnabled, database.chat.botSendLowBatteryWarning {
                sendChatMessage(message: "Moblin bot: \(lowBatteryMessage): \(status)")
            }
        }
        let status = statuses.joined(separator: ", ")
        if status != statusTopRight.djiDevicesStatus {
            statusTopRight.djiDevicesStatus = status
        }
    }

    private func startDjiDeviceLiveStreamInternal(
        djiDevice: DjiDevice,
        device: SettingsDjiDevice
    ) {
        let rtmpUrl: String? = switch device.rtmpUrlType {
        case .server:
            device.serverRtmpUrl ?? automaticServerRtmpUrl(device: device)
        case .custom:
            device.customRtmpUrl
        }
        guard let deviceId = device.bluetoothPeripheralId else {
            return
        }
        if let rtmpUrl {
            djiDevice.startLiveStream(
                wifiSsid: device.wifiSsid,
                wifiPassword: device.wifiPassword,
                rtmpUrl: rtmpUrl,
                resolution: device.resolution,
                fps: device.fps,
                bitrate: device.bitrate,
                videoCodec: device.videoCodec,
                imageStabilization: device.imageStabilization,
                deviceId: deviceId,
                model: device.model
            )
            startDjiDeviceTimer(device: device)
        } else {
            startDjiDeviceRestartTimer(device: device, timeout: 3)
        }
    }

    func automaticServerRtmpUrl(device: SettingsDjiDevice) -> String? {
        guard let stream = getRtmpStream(id: device.serverRtmpStreamId) else {
            return nil
        }
        guard let status = statusOther.ipStatuses
            .first(where: { $0.interfaceType == .wifi && $0.ipType == .ipv4 })
        else {
            return nil
        }
        return rtmpServerStreamUrl(
            address: status.ipType.formatAddress(status.ip),
            port: database.rtmpServer.port,
            streamKey: stream.streamKey
        )
    }

    private func startDjiDeviceTimer(device: SettingsDjiDevice) {
        device.autoRestartStreamTimer.startSingleShot(timeout: 45) { [weak self, weak device] in
            guard let device else {
                return
            }
            self?
                .makeErrorToast(
                    title: String(localized: "Failed to start live stream from DJI device \(device.name)")
                )
            self?.restartDjiLiveStreamIfNeeded(device: device)
        }
    }

    private func startDjiDeviceRestartTimer(device: SettingsDjiDevice, timeout: Double) {
        device.autoRestartStreamTimer.startSingleShot(timeout: timeout) { [weak self, weak device] in
            guard let device else {
                return
            }
            self?.restartDjiLiveStreamIfNeeded(device: device)
        }
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
        guard let djiDevice = djiDevices[device.id] else {
            return
        }
        guard device.isStarted else {
            return
        }
        startDjiDeviceLiveStreamInternal(djiDevice: djiDevice, device: device)
    }

    private func getDjiDeviceSettings(djiDevice: DjiDevice) -> SettingsDjiDevice? {
        database.djiDevices.devices.first(where: { djiDevices[$0.id] === djiDevice })
    }
}

extension Model: @preconcurrency DjiDeviceDelegate {
    func djiDeviceStreamingState(_ device: DjiDevice, state: DjiDeviceState) {
        guard let device = getDjiDeviceSettings(djiDevice: device) else {
            return
        }
        device.state = state
        if device === currentDjiDeviceSettings {
            statusTopRight.djiDeviceStreamingState = state
        }
        switch state {
        case .connecting:
            startDjiDeviceTimer(device: device)
            makeToast(title: String(localized: "Connecting to DJI device \(device.name)"))
        case .streaming:
            if device.rtmpUrlType == .custom {
                device.autoRestartStreamTimer.stop()
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
