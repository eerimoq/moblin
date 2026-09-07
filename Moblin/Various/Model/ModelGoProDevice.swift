import Foundation

extension Model {
    func startGoProDeviceLiveStream(device: SettingsGoProDevice) {
        if !goProDevices.keys.contains(device.id) {
            let goProDevice = GoProDevice()
            goProDevice.delegate = self
            goProDevices[device.id] = goProDevice
        }
        guard let goProDevice = goProDevices[device.id] else {
            return
        }
        device.isStarted = true
        startGoProDeviceLiveStreamInternal(goProDevice: goProDevice, device: device)
    }

    func stopGoProDeviceLiveStream(device: SettingsGoProDevice) {
        device.isStarted = false
        device.autoRestartStreamTimer.stop()
        goProDevices[device.id]?.stopLiveStream()
    }

    func removeGoProDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = database.goPro.devices[offset]
            stopGoProDeviceLiveStream(device: device)
            goProDevices.removeValue(forKey: device.id)
        }
        database.goPro.devices.remove(atOffsets: offsets)
    }

    func autoStartGoProDevices() {
        for device in database.goPro.devices where device.isStarted {
            startGoProDeviceLiveStream(device: device)
        }
    }

    func reloadGoProDevicesAfterSettingsImport() {
        for (deviceId, goProDevice) in goProDevices
            where !database.goPro.devices.contains(where: { $0.id == deviceId })
        {
            goProDevice.stopLiveStream()
            goProDevices.removeValue(forKey: deviceId)
        }
        autoStartGoProDevices()
    }

    func restartGoProLiveStreamIfNeededAfterDelay(device: SettingsGoProDevice) {
        device.autoRestartStreamTimer.startSingleShot(timeout: 5) { [weak self, weak device] in
            guard let device else {
                return
            }
            self?.restartGoProLiveStreamIfNeeded(device: device)
        }
    }

    func markGoProIsStreamingIfNeeded(rtmpServerStreamId: UUID) {
        for device in database.goPro.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId == rtmpServerStreamId else {
                continue
            }
            device.autoRestartStreamTimer.stop()
        }
    }

    func automaticServerRtmpUrl(device: SettingsGoProDevice) -> String? {
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

    private func startGoProDeviceLiveStreamInternal(
        goProDevice: GoProDevice,
        device: SettingsGoProDevice
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
        guard let rtmpUrl else {
            restartGoProLiveStreamIfNeededAfterDelay(device: device)
            return
        }
        goProDevice.startLiveStream(
            wifiSsid: device.wifiSsid,
            wifiPassword: device.wifiPassword,
            rtmpUrl: rtmpUrl,
            resolution: device.resolution,
            bitrate: device.bitrate,
            lens: device.lens,
            deviceId: deviceId
        )
        device.autoRestartStreamTimer.startSingleShot(timeout: 95) { [weak self, weak device] in
            guard let device else {
                return
            }
            self?
                .makeErrorToast(
                    title: String(localized: "Failed to start live stream from GoPro \(device.name)")
                )
            self?.restartGoProLiveStreamIfNeeded(device: device)
        }
    }

    private func restartGoProLiveStreamIfNeeded(device: SettingsGoProDevice) {
        guard device.rtmpUrlType == .server, device.autoRestartStream, device.isStarted,
              let goProDevice = goProDevices[device.id]
        else {
            return
        }
        startGoProDeviceLiveStreamInternal(goProDevice: goProDevice, device: device)
    }

    private func getGoProDeviceSettings(_ goProDevice: GoProDevice) -> SettingsGoProDevice? {
        database.goPro.devices.first(where: { goProDevices[$0.id] === goProDevice })
    }
}

extension Model: @preconcurrency GoProDeviceDelegate {
    func goProDeviceStreamingState(_ goProDevice: GoProDevice, state: GoProDeviceState) {
        guard let device = getGoProDeviceSettings(goProDevice) else {
            return
        }
        device.state = state
        switch state {
        case .connecting:
            makeToast(title: String(localized: "Connecting to GoPro \(device.name)"))
        case .streaming:
            if device.rtmpUrlType == .custom {
                device.autoRestartStreamTimer.stop()
                makeToast(title: String(localized: "GoPro \(device.name) streaming to custom URL"))
            }
        case .wifiSetupFailed:
            makeErrorToast(
                title: String(localized: "WiFi setup failed for GoPro \(device.name)"),
                subTitle: String(localized: "Please check the WiFi settings")
            )
        case .failed:
            makeErrorToast(title: String(localized: "GoPro \(device.name) failed to start streaming"))
            restartGoProLiveStreamIfNeededAfterDelay(device: device)
        default:
            break
        }
    }
}
