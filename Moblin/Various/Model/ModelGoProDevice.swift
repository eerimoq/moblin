import Foundation

final class GoProDeviceWrapper {
    let device: GoProDevice
    let autoRestartStreamTimer = SimpleTimer(queue: .main)

    init(device: GoProDevice) {
        self.device = device
    }
}

extension Model {
    func startGoProDeviceLiveStream(device: SettingsGoProDevice) {
        if !goProDeviceWrappers.keys.contains(device.id) {
            let goProDevice = GoProDevice()
            goProDevice.delegate = self
            goProDeviceWrappers[device.id] = GoProDeviceWrapper(device: goProDevice)
        }
        guard let wrapper = goProDeviceWrappers[device.id] else {
            return
        }
        device.isStarted = true
        startGoProDeviceLiveStreamInternal(wrapper: wrapper, device: device)
    }

    func stopGoProDeviceLiveStream(device: SettingsGoProDevice) {
        device.isStarted = false
        guard let wrapper = goProDeviceWrappers[device.id] else {
            return
        }
        wrapper.autoRestartStreamTimer.stop()
        wrapper.device.stopLiveStream()
    }

    func removeGoProDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = database.goPro.devices[offset]
            stopGoProDeviceLiveStream(device: device)
            goProDeviceWrappers.removeValue(forKey: device.id)
        }
        database.goPro.devices.remove(atOffsets: offsets)
    }

    func autoStartGoProDevices() {
        for device in database.goPro.devices where device.isStarted {
            startGoProDeviceLiveStream(device: device)
        }
    }

    func reloadGoProDevicesAfterSettingsImport() {
        for (deviceId, wrapper) in goProDeviceWrappers
            where !database.goPro.devices.contains(where: { $0.id == deviceId })
        {
            wrapper.device.stopLiveStream()
            wrapper.autoRestartStreamTimer.stop()
            goProDeviceWrappers.removeValue(forKey: deviceId)
        }
        autoStartGoProDevices()
    }

    func restartGoProLiveStreamIfNeededAfterDelay(device: SettingsGoProDevice) {
        guard let wrapper = goProDeviceWrappers[device.id] else {
            return
        }
        wrapper.autoRestartStreamTimer.startSingleShot(timeout: 5) { [weak self] in
            self?.restartGoProLiveStreamIfNeeded(device: device)
        }
    }

    func markGoProIsStreamingIfNeeded(rtmpServerStreamId: UUID) {
        for device in database.goPro.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId == rtmpServerStreamId else {
                continue
            }
            goProDeviceWrappers[device.id]?.autoRestartStreamTimer.stop()
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
        wrapper: GoProDeviceWrapper,
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
        wrapper.device.startLiveStream(
            wifiSsid: device.wifiSsid,
            wifiPassword: device.wifiPassword,
            rtmpUrl: rtmpUrl,
            resolution: device.resolution,
            bitrate: device.bitrate,
            lens: device.lens,
            deviceId: deviceId
        )
        wrapper.autoRestartStreamTimer.startSingleShot(timeout: 95) { [weak self] in
            self?
                .makeErrorToast(
                    title: String(localized: "Failed to start live stream from GoPro \(device.name)")
                )
            self?.restartGoProLiveStreamIfNeeded(device: device)
        }
    }

    private func restartGoProLiveStreamIfNeeded(device: SettingsGoProDevice) {
        guard device.rtmpUrlType == .server, device.autoRestartStream, device.isStarted,
              let wrapper = goProDeviceWrappers[device.id]
        else {
            return
        }
        startGoProDeviceLiveStreamInternal(wrapper: wrapper, device: device)
    }

    private func getGoProDeviceSettings(_ goProDevice: GoProDevice) -> SettingsGoProDevice? {
        database.goPro.devices.first(where: { goProDeviceWrappers[$0.id]?.device === goProDevice })
    }
}

extension Model: @preconcurrency GoProDeviceDelegate {
    func goProDeviceStreamingState(_ goProDevice: GoProDevice, state: GoProDeviceState) {
        guard let device = getGoProDeviceSettings(goProDevice),
              let wrapper = goProDeviceWrappers[device.id]
        else {
            return
        }
        device.state = state
        switch state {
        case .connecting:
            makeToast(title: String(localized: "Connecting to GoPro \(device.name)"))
        case .streaming:
            if device.rtmpUrlType == .custom {
                wrapper.autoRestartStreamTimer.stop()
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
